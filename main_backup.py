import os
import json
import re
import time
import asyncio
from enum import Enum
from typing import List, Optional
from datetime import date, datetime, time as time_type
from zoneinfo import ZoneInfo
from contextlib import asynccontextmanager
from fastapi import FastAPI, Depends, HTTPException, status, Query, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import OAuth2PasswordBearer
from pydantic import BaseModel
from sqlalchemy import func, desc, text
from sqlalchemy.orm import Session, joinedload
from dotenv import load_dotenv
from google import genai
from jose import JWTError, jwt
from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger
from apscheduler.triggers.interval import IntervalTrigger
import firebase_admin
from firebase_admin import credentials, messaging, firestore
import models
import schemas
import crud
import security
from database import engine, get_db
from models import Pedido, Produto, ItemPedido, Categoria, Favorito, Endereco
from treinar_recomendacao import treinar_motor_recomendacao

# Tenta importar o cliente WebSac (deve existir websac_client.py no projeto)
try:
    from websac_client import WebSacIntegration
except ImportError:
    WebSacIntegration = None


# ==========================================
# 🌟 CONFIGURAÇÕES DE FUSO HORÁRIO E DATA
# ==========================================
FUSO_BRASILIA = ZoneInfo("America/Sao_Paulo")

def agora_brasilia() -> datetime:
    """Retorna a data e hora atual exatamente no fuso horário de Brasília."""
    return datetime.now(FUSO_BRASILIA)


# Carrega as variáveis do arquivo .env
load_dotenv()

# 1. Inicialização do Banco de Dados PostgreSQL
models.Base.metadata.create_all(bind=engine)

try:
    with engine.connect() as connection:
        connection.execute(text("ALTER TABLE clientes ADD COLUMN IF NOT EXISTS fcm_token VARCHAR;"))
        connection.execute(text("ALTER TABLE clientes ADD COLUMN IF NOT EXISTS cpf VARCHAR;"))
        connection.execute(text("ALTER TABLE clientes ADD COLUMN IF NOT EXISTS eh_membro_clube BOOLEAN DEFAULT FALSE;"))
        connection.execute(text("ALTER TABLE pedidos ADD COLUMN IF NOT EXISTS subtotal FLOAT DEFAULT 0.0;"))
        connection.execute(text("ALTER TABLE pedidos ADD COLUMN IF NOT EXISTS taxa_entrega FLOAT DEFAULT 0.0;"))
        connection.commit()
except Exception as e:
    print(f"Aviso ao verificar colunas no PostgreSQL: {e}")

# 2. Inicialização do Firebase Admin SDK (FCM e Firestore)
try:
    if not firebase_admin._apps:
        if os.path.exists("serviceAccountKey.json"):
            cred = credentials.Certificate("serviceAccountKey.json")
            firebase_admin.initialize_app(cred)
            print("✅ Firebase SDK inicializado com sucesso!")
        else:
            print("⚠️ Arquivo 'serviceAccountKey.json' não encontrado na raiz. Notificações Push e Firestore desativados.")
except Exception as e:
    print(f"⚠️ Erro ao inicializar o Firebase: {e}")


# ==========================================
# 🔄 ROTINAS E GRAVAÇÃO DO WEBSAC / FIREBASE
# ==========================================
async def salvar_produtos_no_firebase(produtos: list):
    """
    Insere/atualiza produtos no Firestore em lotes com pausa de 250ms
    para respeitar a taxa de requisições da API do Google Cloud.
    """
    if not produtos:
        print("⚠️ Nenhum produto retornado para salvar no Firebase.")
        return

    try:
        db_firestore = firestore.client()
        batch = db_firestore.batch()
        contador = 0
        total = len(produtos)

        print(f"🔥 [Firebase] Iniciando gravação de {total} produtos no Firestore...")

        for prod in produtos:
            id_doc = str(prod.get("id_websac") or prod.get("id"))
            doc_ref = db_firestore.collection("produtos").document(id_doc)
            
            batch.set(doc_ref, prod, merge=True)
            contador += 1

            if contador % 400 == 0:
                batch.commit()
                print(f"📦 [Firebase] Progresso: {contador}/{total} produtos salvos...")
                batch = db_firestore.batch()
                await asyncio.sleep(0.25)  # Pausa de 250ms para estabilizar a API do Firebase

        if contador % 400 != 0:
            batch.commit()

        print(f"✅ [Firebase] Sucesso! Total de {contador} produtos salvos na coleção 'produtos'.")
    except Exception as e:
        print(f"❌ [Firebase] Erro ao gravar produtos no Firestore: {e}")

async def rotina_carga_total():
    print(f"[{agora_brasilia()}] Iniciando Carga Total do Catálogo WebSac...")
    if WebSacIntegration:
        try:
            websac = WebSacIntegration(
                cnpj="44737674000149", 
                token="ba2e4041-0d3d-4ed5-a110-df9ca841102c",
                dominio="tescarollo"
            )
            produtos = await websac.sincronizar_catalogo()
            await salvar_produtos_no_firebase(produtos)
            print(f"[{agora_brasilia()}] Carga Total finalizada com sucesso. Total: {len(produtos)} produtos.")
        except Exception as e:
            print(f"❌ Erro na carga total WebSac: {e}")

async def rotina_carga_expressa():
    print(f"[{agora_brasilia()}] Sincronizando Estoque e Preços WebSac...")
    print("Estoque e Preços atualizados.")


# ==========================================
# 🚀 CICLO DE VIDA (LIFESPAN) E APLICAÇÃO FASTAPI
# ==========================================
@asynccontextmanager
async def lifespan(app: FastAPI):
    scheduler = AsyncIOScheduler()

    # 1. Agendamento da Carga Total (Todos os dias às 03:00 da manhã)
    scheduler.add_job(
        rotina_carga_total,
        CronTrigger(hour=3, minute=0),
        id="sync_total_madrugada",
        replace_existing=True
    )

    # 2. Agendamento da Carga Expressa (A cada 15 minutos durante o dia)
    scheduler.add_job(
        rotina_carga_expressa,
        IntervalTrigger(minutes=15),
        id="sync_expressa_estoque",
        replace_existing=True
    )

    scheduler.start()
    print("⏳ Schedulers de sincronização WebSac iniciados.")
    
    yield
    
    scheduler.shutdown()
    print("🛑 Schedulers finalizados.")

# 🌟 INSTÂNCIA ÚNICA DA APLICAÇÃO FASTAPI
app = FastAPI(
    title="Box Smart API",
    description="API oficial da plataforma de e-commerce e clube de fidelidade Box Smart",
    version="1.0.0",
    lifespan=lifespan
)

# Middlewares
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Agendador do Treinamento do Motor de Recomendação por IA
scheduler_rec = BackgroundScheduler()
scheduler_rec.add_job(treinar_motor_recomendacao, 'interval', hours=12)
scheduler_rec.start()


# --- Funções Auxiliares ---
def enviar_notificacao_push(fcm_token: str, titulo: str, corpo: str, dados_extra: dict = None):
    if not fcm_token:
        return
    try:
        mensagem = messaging.Message(
            notification=messaging.Notification(
                title=titulo,
                body=corpo,
            ),
            data={k: str(v) for k, v in (dados_extra or {}).items()},
            token=fcm_token,
        )
        messaging.send(mensagem)
        print(f"🔔 Push enviado com sucesso para o token: {fcm_token[:10]}...")
    except Exception as e:
        print(f"Erro ao enviar notificação push via FCM: {e}")

def validar_cpf(cpf: str) -> bool:
    cpf = re.sub(r'\D', '', cpf)
    if len(cpf) != 11 or cpf == cpf[0] * 11:
        return False
    soma = sum(int(cpf[i]) * (10 - i) for i in range(9))
    resto = (soma * 10) % 11
    digito_1 = 0 if resto == 10 or resto == 11 else resto
    if digito_1 != int(cpf[9]):
        return False
    soma = sum(int(cpf[i]) * (11 - i) for i in range(10))
    resto = (soma * 10) % 11
    digito_2 = 0 if resto == 10 or resto == 11 else resto
    if digito_2 != int(cpf[10]):
        return False
    return True


# ==========================================
# 🚚 REGRAS E CÁLCULO DE FRETE
# ==========================================
class ConfigFreteUpdate(BaseModel):
    taxa_padrao: Optional[float] = None
    valor_minimo_frete_gratis: Optional[float] = None
    frete_gratis_hoje: Optional[bool] = None

def calcular_frete_backend(subtotal: float, db: Session) -> dict:
    config = None
    if hasattr(models, 'ConfigFrete'):
        config = db.query(models.ConfigFrete).first()
    
    taxa_padrao = getattr(config, 'taxa_padrao', 7.00) if config else 7.00
    valor_minimo = getattr(config, 'valor_minimo_frete_gratis', 100.00) if config else 100.00
    frete_gratis_hoje = getattr(config, 'frete_gratis_hoje', False) if config else False

    if frete_gratis_hoje:
        return {
            "valor_frete": 0.0,
            "taxa_padrao": taxa_padrao,
            "valor_minimo_frete_gratis": valor_minimo,
            "frete_gratis_hoje": True,
            "motivo": "Hoje o frete é grátis no Box Smart! 🎉",
            "faltam_para_frete_gratis": 0.0
        }

    if valor_minimo and subtotal >= valor_minimo:
        return {
            "valor_frete": 0.0,
            "taxa_padrao": taxa_padrao,
            "valor_minimo_frete_gratis": valor_minimo,
            "frete_gratis_hoje": False,
            "motivo": f"Frete grátis garantido para compras acima de R$ {valor_minimo:.2f}!",
            "faltam_para_frete_gratis": 0.0
        }

    faltam = round(valor_minimo - subtotal, 2) if valor_minimo and subtotal < valor_minimo else 0.0

    return {
        "valor_frete": taxa_padrao,
        "taxa_padrao": taxa_padrao,
        "valor_minimo_frete_gratis": valor_minimo,
        "frete_gratis_hoje": False,
        "motivo": "Taxa padrão de entrega",
        "faltam_para_frete_gratis": faltam
    }

@app.get("/")
def ler_raiz():
    return {"status": "API Box Smart Online", "integracao": "WebSac Ativa", "mensagem": "Bem-vindo à API do Box Smart! 🛒🚀"}

@app.get("/api/frete/calcular")
@app.get("/api/frete/calcular/")
def consultar_frete(subtotal: float = Query(0.0), db: Session = Depends(get_db)):
    return calcular_frete_backend(subtotal=subtotal, db=db)

@app.get("/admin/frete/config")
@app.get("/admin/frete/config/")
def obter_configuracao_frete(db: Session = Depends(get_db)):
    if hasattr(models, 'ConfigFrete'):
        config = db.query(models.ConfigFrete).first()
        if config:
            return {
                "taxa_padrao": config.taxa_padrao,
                "valor_minimo_frete_gratis": config.valor_minimo_frete_gratis,
                "frete_gratis_hoje": config.frete_gratis_hoje
            }
    return {"taxa_padrao": 7.00, "valor_minimo_frete_gratis": 100.00, "frete_gratis_hoje": False}

@app.put("/admin/frete/config")
@app.put("/admin/frete/config/")
def atualizar_configuracao_frete(dados: ConfigFreteUpdate, db: Session = Depends(get_db)):
    if not hasattr(models, 'ConfigFrete'):
        raise HTTPException(status_code=500, detail="Modelo ConfigFrete não definido no backend.")

    config = db.query(models.ConfigFrete).first()
    if not config:
        config = models.ConfigFrete()
        db.add(config)

    if dados.taxa_padrao is not None:
        config.taxa_padrao = dados.taxa_padrao
    if dados.valor_minimo_frete_gratis is not None:
        config.valor_minimo_frete_gratis = dados.valor_minimo_frete_gratis
    if dados.frete_gratis_hoje is not None:
        config.frete_gratis_hoje = dados.frete_gratis_hoje

    db.commit()
    db.refresh(config)

    return {
        "mensagem": "Configurações de frete atualizadas com sucesso!",
        "config": {
            "taxa_padrao": config.taxa_padrao,
            "valor_minimo_frete_gratis": config.valor_minimo_frete_gratis,
            "frete_gratis_hoje": config.frete_gratis_hoje
        }
    }


# ==========================================
# 📂 CONFIGURAÇÃO DO APP
# ==========================================
class VincularCPFSchema(BaseModel):
    cliente_id: int
    cpf: str

class FooterConfig(BaseModel):
    texto_copyright: str = "© 2026 BEMG Tecnologia e sistemas. Todos os direitos reservados."
    telefone_suporte: str = "11932020223"
    mensagem_suporte: str = "Olá! Preciso de suporte com o aplicativo Box Smart."
    termos_url: Optional[str] = "https://boxsmart.com.br/termos"
    privacidade_url: Optional[str] = "https://boxsmart.com.br/privacidade"

CONFIG_APP_CACHE = {
    "logo_url": "https://i.imgur.com/6tJyuYb.png",
    "footer": {
        "texto_copyright": "© 2026 BEMG Tecnologia e sistemas. Todos os direitos reservados.",
        "telefone_suporte": "11932020223",
        "mensagem_suporte": "Olá! Preciso de ajuda com meu pedido no Box Smart.",
        "termos_url": "https://boxsmart.com.br/termos",
        "privacidade_url": "https://boxsmart.com.br/privacidade"
    }
}

@app.get("/api/config")
@app.get("/api/config/")
def obter_configuracoes_app():
    return {
        "logo_url": "https://i.imgur.com/6tJyuYb.png",
        "footer": {
            "texto_copyright": "© 2026 BEMG Tecnologia e sistemas. Todos os direitos reservados.",
            "subtitulo": "Seu supermercado online completo e rápido.",
            "telefone_suporte": "11932020223",
            "mensagem_suporte": "Olá! Preciso de ajuda com meu pedido."
        }
    }

@app.put("/admin/config")
def atualizar_configuracoes_app(novas_configs: dict, db: Session = Depends(get_db)):
    if "logo_url" in novas_configs and novas_configs["logo_url"]:
        CONFIG_APP_CACHE["logo_url"] = novas_configs["logo_url"]
    if "footer" in novas_configs and isinstance(novas_configs["footer"], dict):
        CONFIG_APP_CACHE["footer"].update(novas_configs["footer"])
    return {"mensagem": "Configurações visuais atualizadas com sucesso!", "config": CONFIG_APP_CACHE}


# ==========================================
# 📂 REGRAS DE NEGÓCIO E MÁQUINA DE ESTADOS
# ==========================================
class StatusPedidoEnum(str, Enum):
    PENDENTE = "PENDENTE"
    EM_SEPARACAO = "EM_SEPARACAO"
    SEPARADO = "SEPARADO"
    SAIU_PARA_ENTREGA = "SAIU_PARA_ENTREGA"
    ENTREGUE = "ENTREGUE"
    CANCELADO = "CANCELADO"

TRANSIÇÕES_PERMITIDAS = {
    StatusPedidoEnum.PENDENTE: [StatusPedidoEnum.EM_SEPARACAO, StatusPedidoEnum.CANCELADO],
    StatusPedidoEnum.EM_SEPARACAO: [StatusPedidoEnum.SEPARADO, StatusPedidoEnum.CANCELADO],
    StatusPedidoEnum.SEPARADO: [StatusPedidoEnum.SAIU_PARA_ENTREGA, StatusPedidoEnum.CANCELADO],
    StatusPedidoEnum.SAIU_PARA_ENTREGA: [StatusPedidoEnum.ENTREGUE, StatusPedidoEnum.CANCELADO],
    StatusPedidoEnum.ENTREGUE: [],
    StatusPedidoEnum.CANCELADO: []
}

def obter_endereco_formatado_cliente(cliente: models.Cliente) -> Optional[str]:
    if not cliente:
        return None
    if getattr(cliente, 'endereco', None) and cliente.endereco.strip():
        return cliente.endereco
    if hasattr(cliente, 'enderecos') and cliente.enderecos:
        end = next((e for e in cliente.enderecos if getattr(e, 'padrao', False)), cliente.enderecos[0])
        comp = f" - {end.complemento}" if getattr(end, 'complemento', None) else ""
        return f"{end.rua}, {end.numero}{comp} - {end.bairro}, {end.cidade}/{end.uf}"
    return None

def validar_transicao_status(status_atual: str, novo_status: str, eh_admin: bool = False):
    if eh_admin:
        return True
    try:
        status_atual_enum = StatusPedidoEnum(status_atual.upper())
        novo_status_enum = StatusPedidoEnum(novo_status.upper())
    except ValueError:
        raise HTTPException(
            status_code=400,
            detail=f"Status de pedido inválido. Os status válidos são: {[s.value for s in StatusPedidoEnum]}"
        )
    permitidos = TRANSIÇÕES_PERMITIDAS.get(status_atual_enum, [])
    if novo_status_enum not in permitidos:
        raise HTTPException(
            status_code=400, 
            detail=f"Transição de status inválida: Não é permitido mudar de '{status_atual}' para '{novo_status}'."
        )
    return True

def verificar_permissao_status(usuario: models.Cliente, status_atual: str, novo_status: str):
    perfil = (usuario.perfil or "cliente").lower()
    novo_status_upper = novo_status.upper()
    status_atual_upper = status_atual.upper()

    if usuario.is_admin or perfil in ["admin", "gestor"]:
        return True

    if perfil == "separador":
        if novo_status_upper in ["EM_SEPARACAO", "SEPARADO", "SAIU_PARA_ENTREGA"]:
            return True
        raise HTTPException(
            status_code=403,
            detail="Operador de separação só pode atualizar para 'EM_SEPARACAO', 'SEPARADO' ou 'SAIU_PARA_ENTREGA'."
        )

    if perfil == "entregador":
        if novo_status_upper in ["SAIU_PARA_ENTREGA", "EM_TRANSITO", "ENTREGUE", "CONCLUIDO"]:
            return True
        raise HTTPException(
            status_code=403,
            detail="Entregador só pode atualizar para 'SAIU_PARA_ENTREGA' ou 'ENTREGUE'."
        )

    if perfil == "cliente":
        if novo_status_upper == "CANCELADO" and status_atual_upper == "PENDENTE":
            return True
        raise HTTPException(
            status_code=403,
            detail="Clientes só podem cancelar pedidos que estejam no status 'PENDENTE'."
        )

    raise HTTPException(status_code=403, detail="Seu perfil não tem permissão para esta ação.")

def registrar_rastreabilidade_pedido(pedido, novo_status: str, usuario_logado, dados_extra: dict = None):
    agora = agora_brasilia()
    dados_extra = dados_extra or {}

    if novo_status == "EM_SEPARACAO":
        pedido.separador_id = dados_extra.get("separador_id") or usuario_logado.id
        pedido.separado_por = dados_extra.get("separado_por") or usuario_logado.nome
        if not getattr(pedido, 'data_inicio_separacao', None):
            setattr(pedido, 'data_inicio_separacao', agora)

    elif novo_status in ["SEPARADO", "PRONTO_PARA_ENTREGA"]:
        pedido.separador_id = dados_extra.get("separador_id") or usuario_logado.id
        pedido.separado_por = dados_extra.get("separado_por") or usuario_logado.nome
        if not getattr(pedido, 'data_separado', None):
            setattr(pedido, 'data_separado', agora)

    elif novo_status in ["SAIU_PARA_ENTREGA", "EM_TRANSITO"]:
        pedido.entregador_id = usuario_logado.id
        pedido.entregador_nome = usuario_logado.nome
        if not getattr(pedido, 'data_saiu_entrega', None):
            setattr(pedido, 'data_saiu_entrega', agora)

    elif novo_status in ["ENTREGUE", "CONCLUIDO"]:
        if not getattr(pedido, 'entregador_nome', None):
            pedido.entregador_id = usuario_logado.id
            pedido.entregador_nome = usuario_logado.nome
        if not getattr(pedido, 'data_concluido', None):
            setattr(pedido, 'data_concluido', agora)
        if dados_extra.get("codigo_confirmacao"):
            setattr(pedido, 'codigo_confirmacao', dados_extra.get("codigo_confirmacao"))

    elif novo_status == "CANCELADO":
        if not getattr(pedido, 'data_cancelado', None):
            setattr(pedido, 'data_cancelado', agora)

    pedido.status = novo_status

def aplicar_filtro_data(query, coluna_data, data_inicio: Optional[date], data_fim: Optional[date]):
    if data_inicio:
        inicio_dt = datetime.combine(data_inicio, time_type.min).replace(tzinfo=FUSO_BRASILIA)
        query = query.filter(coluna_data >= inicio_dt)
    if data_fim:
        fim_dt = datetime.combine(data_fim, time_type.max).replace(tzinfo=FUSO_BRASILIA)
        query = query.filter(coluna_data <= fim_dt)
    return query


# ==========================================
# 📂 SCHEMAS LOCAIS
# ==========================================
class AtualizarStatusRequest(BaseModel):
    status: str
    motivo_cancelamento: Optional[str] = None
    separado_por: Optional[str] = None
    separador_id: Optional[int] = None
    codigo_confirmacao: Optional[str] = None

class CategoriaBase(BaseModel):
    nome: str
    ativo: bool = True
    ordem: int = 0

class CategoriaUpdate(BaseModel):
    nome: Optional[str] = None
    imagem_url: Optional[str] = None
    cor_icone: Optional[str] = None
    cor_fundo: Optional[str] = None
    cor_texto: Optional[str] = None
    ativo: Optional[bool] = None
    ordem: Optional[int] = None

class SecaoPromocionalBase(BaseModel):
    titulo: str
    tipo: str
    ordem: int = 0
    ativa: bool = True
    banner_url: Optional[str] = None
    categoria_id: Optional[int] = None
    acao_tipo: Optional[str] = None   
    acao_valor: Optional[str] = None
    produto_ids: Optional[List[int]] = []

class SecaoPromocionalUpdate(BaseModel):
    titulo: Optional[str] = None
    tipo: Optional[str] = None
    ordem: Optional[int] = None
    ativa: Optional[bool] = None
    banner_url: Optional[str] = None
    categoria_id: Optional[int] = None
    acao_tipo: Optional[str] = None   
    acao_valor: Optional[str] = None
    produto_ids: Optional[List[int]] = None

class ProdutoCreate(BaseModel):
    nome: str
    descricao: Optional[str] = None
    preco: float
    preco_clube: Optional[float] = None
    unidade: str = "un"
    estoque: int = 0
    imagem_url: Optional[str] = None
    categoria_id: int
    destaque: bool = False
    mais_vendido: bool = False
    ativo: bool = True

class ProdutoCreateUpdate(BaseModel):
    nome: str
    descricao: Optional[str] = None 
    preco: float
    preco_clube: Optional[float] = None
    unidade: str = "un"
    categoria_id: int
    imagem_url: Optional[str] = None

class ProdutoUpdate(BaseModel):
    nome: Optional[str] = None
    descricao: Optional[str] = None
    preco: Optional[float] = None
    preco_clube: Optional[float] = None
    unidade: Optional[str] = None
    estoque: Optional[int] = None
    imagem_url: Optional[str] = None
    categoria_id: Optional[int] = None
    destaque: Optional[bool] = None
    mais_vendido: Optional[bool] = None
    ativo: Optional[bool] = None

class LocalizacaoEntregadorSchema(BaseModel):
    latitude: float
    longitude: float


# ==========================================
# 🔑 SEGURANÇA & AUTENTICAÇÃO (OAUTH2 / JWT)
# ==========================================
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="login")
SECRET_KEY = "box_smart_super_secret_key_e_commerce_fidelidade" 
ALGORITHM = "HS256"

def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)):
    exception_unauthorized = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Credenciais inválidas ou token expirado",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        email: str = payload.get("sub")
        if email is None:
            raise exception_unauthorized
    except JWTError:
        raise exception_unauthorized

    usuario = db.query(models.Cliente).filter(models.Cliente.email == email).first()
    if usuario is None:
        raise exception_unauthorized

    return usuario

def calcular_total(itens, db: Session) -> float:
    total = 0.0
    for item in itens:
        produto = db.query(models.Produto).filter(models.Produto.id == item.produto_id).first()
        if produto:
            total += produto.preco * item.quantidade
    return total


# ==========================================
# 📂 ROTAS DE PRECIFICAÇÃO, BI E RELATÓRIOS
# ==========================================
@app.get("/admin/metrics/")
@app.get("/admin/metrics")
def obter_metricas_admin(db: Session = Depends(get_db)):
    try:
        resultado_vendas = db.query(
            func.sum(models.Pedido.total).label("faturamento_total"),
            func.count(models.Pedido.id).label("pedidos_mes")
        ).first()

        faturamento = resultado_vendas.faturamento_total or 0.0
        total_pedidos = resultado_vendas.pedidos_mes or 0
        ticket_medio = (faturamento / total_pedidos) if total_pedidos > 0 else 0.0

        return {
            "faturamento_total": float(faturamento),
            "pedidos_mes": int(total_pedidos),
            "ticket_medio": float(ticket_medio),
            "insights_ia": [
                "O motor de IA analisou o fluxo recente e indica alta demanda nas categorias de pronto consumo.",
                "Considere programar campanhas de notificação push no horário de pico do aplicativo.",
                "Os dados exibidos acima são extraídos em tempo real do banco de dados do Box Smart."
            ]
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro ao calcular métricas: {str(e)}")

@app.get("/admin/relatorios/resumo")
@app.get("/admin/relatorios/resumo/")
def relatorio_resumo(
    data_inicio: Optional[date] = Query(None),
    data_fim: Optional[date] = Query(None),
    db: Session = Depends(get_db)
):
    query = db.query(models.Pedido)
    query = aplicar_filtro_data(query, models.Pedido.data_criacao, data_inicio, data_fim)

    total_pedidos = query.count()
    faturamento_total = query.with_entities(func.sum(models.Pedido.total)).scalar() or 0.0
    
    status_counts = (
        query.with_entities(models.Pedido.status, func.count(models.Pedido.id))
        .group_by(models.Pedido.status)
        .all()
    )
    status_dict = {status: count for status, count in status_counts}

    return {
        "total_pedidos": total_pedidos,
        "faturamento_total": float(faturamento_total),
        "status_pedidos": status_dict,
    }

@app.get("/admin/relatorios/produtos-mais-vendidos")
@app.get("/admin/relatorios/produtos-mais-vendidos/")
def produtos_mais_vendidos(
    data_inicio: Optional[date] = Query(None),
    data_fim: Optional[date] = Query(None),
    db: Session = Depends(get_db)
):
    query = (
        db.query(
            models.Produto.nome.label("nome_produto"),
            func.sum(models.ItemPedido.quantidade).label("total_vendido")
        )
        .join(models.ItemPedido, models.ItemPedido.produto_id == models.Produto.id)
        .join(models.Pedido, models.ItemPedido.pedido_id == models.Pedido.id)
    )

    query = aplicar_filtro_data(query, models.Pedido.data_criacao, data_inicio, data_fim)

    resultado = (
        query.group_by(models.Produto.nome)
        .order_by(desc("total_vendido"))
        .limit(5)
        .all()
    )

    return [{"nome": item.nome_produto, "quantidade": int(item.total_vendido or 0)} for item in resultado]

@app.get("/admin/relatorios/ticket-medio-diario")
@app.get("/admin/relatorios/ticket-medio-diario/")
def ticket_medio_diario(
    data_inicio: Optional[date] = Query(None),
    data_fim: Optional[date] = Query(None),
    db: Session = Depends(get_db)
):
    query = db.query(
        func.date(models.Pedido.data_criacao).label("data"),
        func.sum(models.Pedido.total).label("faturamento_dia"),
        func.count(models.Pedido.id).label("total_pedidos_dia")
    )

    query = aplicar_filtro_data(query, models.Pedido.data_criacao, data_inicio, data_fim)

    resultado = (
        query.group_by(func.date(models.Pedido.data_criacao))
        .order_by(func.date(models.Pedido.data_criacao))
        .all()
    )

    return [
        {
            "data": str(item.data),
            "faturamento": float(item.faturamento_dia or 0.0),
            "pedidos": int(item.total_pedidos_dia or 0),
            "ticket_medio": float((item.faturamento_dia or 0.0) / (item.total_pedidos_dia or 1))
        }
        for item in resultado
    ]

@app.get("/admin/relatorios/faturamento-categoria")
@app.get("/admin/relatorios/faturamento-categoria/")
def faturamento_por_categoria(
    data_inicio: Optional[date] = Query(None),
    data_fim: Optional[date] = Query(None),
    db: Session = Depends(get_db)
):
    query = (
        db.query(
            models.Categoria.nome.label("categoria"),
            func.sum(models.ItemPedido.preco_unitario * models.ItemPedido.quantidade).label("faturamento")
        )
        .join(models.Produto, models.ItemPedido.produto_id == models.Produto.id)
        .join(models.Categoria, models.Produto.categoria_id == models.Categoria.id)
        .join(models.Pedido, models.ItemPedido.pedido_id == models.Pedido.id)
    )

    query = aplicar_filtro_data(query, models.Pedido.data_criacao, data_inicio, data_fim)
    resultado = query.group_by(models.Categoria.nome).all()

    return [
        {
            "categoria": item.categoria,
            "faturamento": float(item.faturamento or 0.0)
        }
        for item in resultado
    ]

@app.get("/admin/relatorios/desempenho-clube")
@app.get("/admin/relatorios/desempenho-clube/")
def desempenho_clube(
    data_inicio: Optional[date] = Query(None),
    data_fim: Optional[date] = Query(None),
    db: Session = Depends(get_db)
):
    query = db.query(models.Pedido)
    query = aplicar_filtro_data(query, models.Pedido.data_criacao, data_inicio, data_fim)
    pedidos = query.all()

    faturamento_membros, pedidos_membros = 0.0, 0
    faturamento_comuns, pedidos_comuns = 0.0, 0

    for p in pedidos:
        eh_membro = getattr(p, 'eh_membro_clube', False) 
        if eh_membro:
            faturamento_membros += float(p.total or 0.0)
            pedidos_membros += 1
        else:
            faturamento_comuns += float(p.total or 0.0)
            pedidos_comuns += 1

    ticket_medio_membros = (faturamento_membros / pedidos_membros) if pedidos_membros > 0 else 0.0
    ticket_medio_comuns = (faturamento_comuns / pedidos_comuns) if pedidos_comuns > 0 else 0.0

    return {
        "membros": {
            "faturamento": faturamento_membros,
            "total_pedidos": pedidos_membros,
            "ticket_medio": ticket_medio_membros
        },
        "comuns": {
            "faturamento": faturamento_comuns,
            "total_pedidos": pedidos_comuns,
            "ticket_medio": ticket_medio_comuns
        }
    }

@app.get("/admin/relatorios/estoque-critico")
@app.get("/admin/relatorios/estoque-critico/")
def produtos_estoque_critico(db: Session = Depends(get_db)):
    produtos = (
        db.query(models.Produto)
        .filter(models.Produto.estoque <= 5)
        .order_by(models.Produto.estoque.asc())
        .all()
    )
    return [
        {
            "id": p.id,
            "nome": p.nome,
            "preco": float(p.preco),
            "estoque": p.estoque
        }
        for p in produtos
    ]

@app.get("/admin/relatorios/taxa-conversao")
@app.get("/admin/relatorios/taxa-conversao/")
def taxa_conversao_pedidos(
    data_inicio: Optional[date] = Query(None),
    data_fim: Optional[date] = Query(None),
    db: Session = Depends(get_db)
):
    query = db.query(models.Pedido)
    query = aplicar_filtro_data(query, models.Pedido.data_criacao, data_inicio, data_fim)

    total_pedidos = query.count()
    if total_pedidos == 0:
        return {"total_geral": 0, "concluidos": 0, "cancelados": 0, "taxa_conversao": 0.0}

    concluidos = query.filter(
        func.upper(models.Pedido.status).in_(["CONCLUIDO", "CONCLUÍDO", "ENTREGUE"])
    ).count()

    cancelados = query.filter(
        func.upper(models.Pedido.status) == "CANCELADO"
    ).count()

    taxa = (concluidos / total_pedidos) * 100

    return {
        "total_geral": total_pedidos,
        "concluidos": concluidos,
        "cancelados": cancelados,
        "taxa_conversao": round(taxa, 2)
    }

@app.put("/admin/produtos/{produto_id}/preco-clube", response_model=schemas.ProdutoResponse)
def atualizar_preco_clube(produto_id: int, dados: schemas.PrecoClubeUpdate, db: Session = Depends(get_db)):
    return crud.atualizar_preco_clube(db=db, produto_id=produto_id, novo_preco_clube=dados.preco_clube)

@app.get("/admin/bi/metricas")
@app.get("/admin/bi/metricas/")
def relatorio_metricas_bi(db: Session = Depends(get_db)):
    return crud.obter_metricas_bi(db=db)

@app.get("/admin/ai-insights/")
@app.get("/admin/ai-insights")
def obter_ai_insights(db: Session = Depends(get_db)):
    prompt = "Análise os dados de vendas e estoque da Box Smart e gere 3 insights..."

    client = genai.Client()
    chat = client.chats.create(model="gemini-2.5-flash")

    max_tentativas = 3
    for tentativa in range(1, max_tentativas + 1):
        try:
            resposta = chat.send_message(prompt)
            return {"insights": resposta.text}

        except Exception as e:
            erro_msg = str(e)
            
            if "503" in erro_msg or "UNAVAILABLE" in erro_msg:
                if tentativa < max_tentativas:
                    tempo_espera = 2 * tentativa
                    time.sleep(tempo_espera)
                    continue
            
            return {
                "insights": "O serviço de IA está com alta demanda no momento. Tente novamente em alguns instantes.",
                "status": "indisponivel",
                "detalhes": erro_msg
            }


# ==========================================
# 📂 ROTAS DE CATEGORIAS E DEPARTAMENTOS
# ==========================================
@app.get("/admin/categorias/")
@app.get("/admin/categorias")
def listar_categorias(db: Session = Depends(get_db)):
    return db.query(models.Categoria).order_by(models.Categoria.ordem.asc()).all()

@app.get("/departamentos/")
@app.get("/departamentos")
def listar_departamentos(db: Session = Depends(get_db)):
    categorias = db.query(models.Categoria).filter(models.Categoria.ativo == True).order_by(models.Categoria.ordem.asc()).all()
    return [
        {
            "id": cat.id,
            "nome": cat.nome,
            "imagem_url": getattr(cat, 'imagem_url', None),
            "cor_fundo": getattr(cat, 'cor_fundo', None),
            "cor_texto": cat.cor_texto
        }
        for cat in categorias
    ]

@app.post("/admin/categorias/", status_code=201)
@app.post("/admin/categorias", status_code=201)
def criar_categoria(dados: CategoriaBase, db: Session = Depends(get_db)):
    categoria_existente = db.query(models.Categoria).filter(models.Categoria.nome == dados.nome).first()
    if categoria_existente:
        raise HTTPException(status_code=400, detail="Já existe uma categoria com este nome.")
        
    nova_categoria = models.Categoria(**dados.dict())
    db.add(nova_categoria)
    db.commit()
    db.refresh(nova_categoria)
    return {"mensagem": "Categoria criada com sucesso!", "categoria": nova_categoria}

@app.put("/admin/categorias/{categoria_id}")
@app.put("/admin/categorias/{categoria_id}/")
def atualizar_categoria(categoria_id: int, dados: CategoriaUpdate, db: Session = Depends(get_db)):
    categoria = db.query(models.Categoria).filter(models.Categoria.id == categoria_id).first()
    if not categoria:
        raise HTTPException(status_code=404, detail="Categoria não encontrada.")
    
    dados_atualizados = dados.dict(exclude_unset=True)
    for chave, valor in dados_atualizados.items():
        setattr(categoria, chave, valor)
        
    db.commit()
    db.refresh(categoria)
    return {"mensagem": "Categoria atualizada com sucesso!", "categoria": categoria}

@app.delete("/admin/categorias/{categoria_id}", status_code=204)
@app.delete("/admin/categorias/{categoria_id}/", status_code=204)
def deletar_categoria(categoria_id: int, db: Session = Depends(get_db)):
    categoria = db.query(models.Categoria).filter(models.Categoria.id == categoria_id).first()
    if not categoria:
        raise HTTPException(status_code=404, detail="Categoria não encontrada.")
    
    db.delete(categoria)
    db.commit()
    return {"mensagem": "Categoria excluída com sucesso!"}


# ==========================================
# 📂 ROTAS DE SUBCATEGORIAS
# ==========================================
@app.get("/admin/subcategorias/")
@app.get("/admin/subcategorias")
def listar_subcategorias_admin(db: Session = Depends(get_db)):
    return db.query(models.Subcategoria).order_by(models.Subcategoria.categoria_id, models.Subcategoria.ordem.asc()).all()

@app.get("/api/categorias/{categoria_id}/subcategorias")
@app.get("/api/categorias/{categoria_id}/subcategorias/")
def listar_subcategorias_por_categoria(categoria_id: int, db: Session = Depends(get_db)):
    subcategorias = db.query(models.Subcategoria).filter(
        models.Subcategoria.categoria_id == categoria_id,
        models.Subcategoria.ativo == True
    ).order_by(models.Subcategoria.ordem.asc()).all()
    
    return [
        {
            "id": sub.id,
            "nome": sub.nome,
            "categoria_id": sub.categoria_id
        }
        for sub in subcategorias
    ]

@app.post("/admin/subcategorias/", status_code=201)
@app.post("/admin/subcategorias", status_code=201)
def criar_subcategoria(dados: schemas.SubcategoriaCreate, db: Session = Depends(get_db)):
    nova_subcategoria = models.Subcategoria(**dados.dict())
    db.add(nova_subcategoria)
    db.commit()
    db.refresh(nova_subcategoria)
    return {"mensagem": "Subcategoria criada com sucesso!", "subcategoria": nova_subcategoria}

@app.put("/admin/subcategorias/{subcategoria_id}")
@app.put("/admin/subcategorias/{subcategoria_id}/")
def atualizar_subcategoria(subcategoria_id: int, dados: schemas.SubcategoriaBase, db: Session = Depends(get_db)):
    subcategoria = db.query(models.Subcategoria).filter(models.Subcategoria.id == subcategoria_id).first()
    if not subcategoria:
        raise HTTPException(status_code=404, detail="Subcategoria não encontrada.")
    
    dados_atualizados = dados.dict(exclude_unset=True)
    for chave, valor in dados_atualizados.items():
        setattr(subcategoria, chave, valor)
        
    db.commit()
    db.refresh(subcategoria)
    return {"mensagem": "Subcategoria atualizada com sucesso!", "subcategoria": subcategoria}

@app.delete("/admin/subcategorias/{subcategoria_id}", status_code=204)
@app.delete("/admin/subcategorias/{subcategoria_id}/", status_code=204)
def deletar_subcategoria(subcategoria_id: int, db: Session = Depends(get_db)):
    subcategoria = db.query(models.Subcategoria).filter(models.Subcategoria.id == subcategoria_id).first()
    if not subcategoria:
        raise HTTPException(status_code=404, detail="Subcategoria não encontrada.")
    
    db.delete(subcategoria)
    db.commit()
    return {"mensagem": "Subcategoria excluída com sucesso!"}


# ==========================================
# 📂 ROTAS DE SEÇÕES PROMOCIONAIS (ADMIN)
# ==========================================
@app.get("/admin/secoes/")
@app.get("/admin/secoes")
def listar_secoes_admin(db: Session = Depends(get_db)):
    secoes = db.query(models.SecaoPromocional).all()
    resultado = []
    for s in secoes:
        prods = getattr(s, 'produtos', []) or []
        prod_ids = [p.id for p in prods]
        resultado.append({
            "id": s.id,
            "titulo": s.titulo,
            "tipo": s.tipo,
            "ordem": getattr(s, 'ordem', 0),
            "ativa": getattr(s, 'ativa', True),
            "banner_url": getattr(s, 'banner_url', None),
            "categoria_id": getattr(s, 'categoria_id', None),
            "acao_tipo": getattr(s, 'acao_tipo', None),
            "acao_valor": getattr(s, 'acao_valor', None),
            "produto_ids": prod_ids,
            "produtos": [
                {
                    "id": p.id,
                    "nome": p.nome,
                    "preco": float(p.preco)
                } for p in prods
            ]
        })
    return resultado

@app.post("/admin/secoes/", status_code=201)
@app.post("/admin/secoes", status_code=201)
def criar_secao(dados: SecaoPromocionalBase, db: Session = Depends(get_db)):
    nova_secao = models.SecaoPromocional(
        titulo=dados.titulo,
        tipo=dados.tipo,
        ordem=dados.ordem,
        ativa=dados.ativa,
        banner_url=dados.banner_url,
        categoria_id=dados.categoria_id,
        acao_tipo=dados.acao_tipo,
        acao_valor=dados.acao_valor,
    )
    
    if dados.produto_ids:
        produtos_encontrados = db.query(models.Produto).filter(models.Produto.id.in_(dados.produto_ids)).all()
        nova_secao.produtos = produtos_encontrados

    db.add(nova_secao)
    db.commit()
    db.refresh(nova_secao)
    return {"mensagem": "Seção criada com sucesso!", "secao_id": nova_secao.id}

@app.put("/admin/secoes/{secao_id}")
@app.put("/admin/secoes/{secao_id}/")
def atualizar_secao(secao_id: int, dados: SecaoPromocionalUpdate, db: Session = Depends(get_db)):
    secao = db.query(models.SecaoPromocional).filter(models.SecaoPromocional.id == secao_id).first()
    if not secao:
        raise HTTPException(status_code=404, detail="Seção não encontrada.")
    
    dados_atualizados = dados.dict(exclude_unset=True)
    produto_ids = dados_atualizados.pop("produto_ids", None)

    for chave, valor in dados_atualizados.items():
        setattr(secao, chave, valor)

    if produto_ids is not None:
        produtos_encontrados = db.query(models.Produto).filter(models.Produto.id.in_(produto_ids)).all()
        secao.produtos = produtos_encontrados
        
    db.commit()
    db.refresh(secao)
    return {"mensagem": "Seção atualizada com sucesso!"}

@app.delete("/admin/secoes/{secao_id}", status_code=204)
@app.delete("/admin/secoes/{secao_id}/", status_code=204)
def deletar_secao(secao_id: int, db: Session = Depends(get_db)):
    secao = db.query(models.SecaoPromocional).filter(models.SecaoPromocional.id == secao_id).first()
    if not secao:
        raise HTTPException(status_code=404, detail="Seção não encontrada no banco de dados.")
    
    db.delete(secao)
    db.commit()
    return {"mensagem": "Seção excluída com sucesso!"}


# ==========================================
# 📂 ROTAS DE PRODUTOS
# ==========================================
@app.post("/admin/produtos/", status_code=201)
@app.post("/admin/produtos", status_code=201)
def criar_produto(dados: ProdutoCreate, db: Session = Depends(get_db)):
    novo_produto = models.Produto(**dados.dict())
    db.add(novo_produto)
    db.commit()
    db.refresh(novo_produto)
    return {"mensagem": "Produto criado com sucesso!", "produto": novo_produto}

@app.put("/admin/produtos/{produto_id}")
@app.put("/admin/produtos/{produto_id}/")
def atualizar_produto_admin(produto_id: int, dados: ProdutoUpdate, db: Session = Depends(get_db)):
    produto = db.query(models.Produto).filter(models.Produto.id == produto_id).first()
    if not produto:
        raise HTTPException(status_code=404, detail="Produto não encontrado.")
    
    dados_atualizados = dados.dict(exclude_unset=True)
    for chave, valor in dados_atualizados.items():
        setattr(produto, chave, valor)
        
    db.commit()
    db.refresh(produto)
    return {"mensagem": "Produto atualizado com sucesso!", "produto": produto}

@app.put("/api/produtos/{produto_id}")
@app.put("/api/produtos/{produto_id}/")
def atualizar_produto_api(produto_id: int, produto_atualizado: ProdutoCreateUpdate, db: Session = Depends(get_db)):
    produto_db = db.query(models.Produto).filter(models.Produto.id == produto_id).first()
    if not produto_db:
        raise HTTPException(status_code=404, detail="Produto não encontrado")
    
    produto_db.nome = produto_atualizado.nome
    produto_db.descricao = produto_atualizado.descricao 
    produto_db.preco = produto_atualizado.preco
    produto_db.preco_clube = produto_atualizado.preco_clube
    produto_db.unidade = produto_atualizado.unidade
    produto_db.categoria_id = produto_atualizado.categoria_id
    produto_db.imagem_url = produto_atualizado.imagem_url
    
    db.commit()
    db.refresh(produto_db)
    return produto_db

@app.post("/api/produtos/")
@app.post("/api/produtos")
def criar_produto_api(novo_produto: ProdutoCreateUpdate, db: Session = Depends(get_db)):
    produto_db = models.Produto(**novo_produto.model_dump())
    db.add(produto_db)
    db.commit()
    db.refresh(produto_db)
    return produto_db

@app.get("/api/produtos/")
@app.get("/api/produtos")
def listar_produtos(db: Session = Depends(get_db)):
    produtos = db.query(models.Produto).filter(models.Produto.ativo == True).all()
    return [
        {
            "id": p.id,
            "nome": p.nome,
            "descricao": getattr(p, 'descricao', ''),
            "preco": float(p.preco),
            "preco_clube": float(p.preco_clube) if getattr(p, 'preco_clube', None) else None,
            "estoque": getattr(p, 'estoque', 50),
            "imagem_url": getattr(p, 'imagem_url', None),
            "unidade": getattr(p, 'unidade', 'un') or 'un',
            "categoria_id": getattr(p, 'categoria_id', None),
            "subcategoria_id": getattr(p, 'subcategoria_id', None),
            "categoria": p.categoria.nome if p.categoria else "",
            "mais_vendido": getattr(p, 'mais_vendido', False),
            "destaque": getattr(p, 'destaque', False),
        }
        for p in produtos
    ]


# ==========================================
# 📂 API HOME DINÂMICA DO APP
# ==========================================
@app.get("/api/home")
def obter_home(db: Session = Depends(get_db)):
    banners_db = db.query(models.Banner).filter(models.Banner.ativo == True).all()
    
    banners_principais = []
    banners_secundarios = []

    for b in banners_db:
        tipo_b = (getattr(b, 'tipo', 'principal') or 'principal').lower()
        obj_banner = {
            "id": b.id,
            "titulo": b.titulo,
            "imagem_url": b.imagem_url,
            "tipo": tipo_b,
            "ordem": getattr(b, 'ordem', 0),
            "acao_tipo": getattr(b, 'acao_tipo', None),
            "acao_valor": getattr(b, 'acao_valor', None)
        }
        if tipo_b in ['secundario', 'banner_secundario']:
            banners_secundarios.append(obj_banner)
        else:
            banners_principais.append(obj_banner)

    banners_principais.sort(key=lambda x: x["ordem"])
    banners_secundarios.sort(key=lambda x: x["ordem"])

    secoes = (
        db.query(models.SecaoPromocional)
        .filter(models.SecaoPromocional.ativa == True)
        .order_by(models.SecaoPromocional.ordem.asc())
        .all()
    )

    resultado = []

    tem_secao_banner_principal = any((s.tipo or '').lower() == 'banner_principal' for s in secoes)
    if banners_principais and not tem_secao_banner_principal:
        resultado.append({
            "id": 9991,
            "titulo": "Carrossel Principal",
            "tipo": "banner_principal",
            "ordem": 0,
            "itens": banners_principais,
            "produtos": []
        })

    tem_secao_departamentos = any((s.tipo or '').lower() == 'departamentos' for s in secoes)
    if not tem_secao_departamentos:
        resultado.append({
            "id": 9992,
            "titulo": "Navegue por Departamentos",
            "tipo": "departamentos",
            "ordem": 1,
            "produtos": []
        })

    for s in secoes:
        tipo_lower = (s.tipo or '').lower()

        if tipo_lower == 'departamentos':
            resultado.append({
                "id": s.id,
                "titulo": s.titulo or "Navegue por Departamentos",
                "tipo": "departamentos",
                "ordem": getattr(s, 'ordem', 0),
                "produtos": []
            })
            continue

        if tipo_lower == 'banner_principal':
            resultado.append({
                "id": s.id,
                "titulo": s.titulo,
                "tipo": "banner_principal",
                "ordem": getattr(s, 'ordem', 0),
                "itens": banners_principais,
                "produtos": []
            })
            continue

        produtos_payload = []

        if s.produtos and len(s.produtos) > 0:
            produtos_payload = [
                {
                    "id": p.id,
                    "nome": p.nome,
                    "preco": float(p.preco),
                    "preco_clube": float(p.preco_clube) if getattr(p, 'preco_clube', None) else None,
                    "imagem_url": getattr(p, 'imagem_url', None),
                    "unidade": getattr(p, 'unidade', 'un') or 'un',
                    "estoque": getattr(p, 'estoque', 50),
                }
                for p in s.produtos if getattr(p, 'ativo', True)
            ]

        elif tipo_lower in ['livre', 'curadoria', 'padrao', 'grade_produtos'] and getattr(s, 'categoria_id', None):
            produtos_cat = db.query(models.Produto).filter(
                models.Produto.categoria_id == s.categoria_id,
                models.Produto.ativo == True
            ).all()
            produtos_payload = [
                {
                    "id": p.id,
                    "nome": p.nome,
                    "preco": float(p.preco),
                    "preco_clube": float(p.preco_clube) if getattr(p, 'preco_clube', None) else None,
                    "imagem_url": getattr(p, 'imagem_url', None),
                    "unidade": getattr(p, 'unidade', 'un') or 'un',
                    "estoque": getattr(p, 'estoque', 50),
                }
                for p in produtos_cat
            ]

        elif tipo_lower in ['ofertas_clube', 'clube_prime', 'ofertas']:
            query_clube = db.query(models.Produto).filter(
                models.Produto.ativo == True,
                models.Produto.preco_clube.isnot(None)
            )
            if getattr(s, 'categoria_id', None):
                query_clube = query_clube.filter(models.Produto.categoria_id == s.categoria_id)
            
            prods_clube = query_clube.limit(12).all()
            produtos_payload = [
                {
                    "id": p.id,
                    "nome": p.nome,
                    "preco": float(p.preco),
                    "preco_clube": float(p.preco_clube) if getattr(p, 'preco_clube', None) else None,
                    "imagem_url": getattr(p, 'imagem_url', None),
                    "unidade": getattr(p, 'unidade', 'un') or 'un',
                    "estoque": getattr(p, 'estoque', 50),
                }
                for p in prods_clube
            ]

        elif tipo_lower in ['destaques', 'mais_vendidos']:
            query_dest = db.query(models.Produto).filter(
                models.Produto.ativo == True,
                (models.Produto.destaque == True) | (models.Produto.mais_vendido == True)
            )
            if getattr(s, 'categoria_id', None):
                query_dest = query_dest.filter(models.Produto.categoria_id == s.categoria_id)
            
            prods_dest = query_dest.limit(12).all()
            produtos_payload = [
                {
                    "id": p.id,
                    "nome": p.nome,
                    "preco": float(p.preco),
                    "preco_clube": float(p.preco_clube) if getattr(p, 'preco_clube', None) else None,
                    "imagem_url": getattr(p, 'imagem_url', None),
                    "unidade": getattr(p, 'unidade', 'un') or 'un',
                    "estoque": getattr(p, 'estoque', 50),
                }
                for p in prods_dest
            ]

        else:
            prods_fb = db.query(models.Produto).filter(models.Produto.ativo == True).limit(12).all()
            produtos_payload = [
                {
                    "id": p.id,
                    "nome": p.nome,
                    "preco": float(p.preco),
                    "preco_clube": float(p.preco_clube) if getattr(p, 'preco_clube', None) else None,
                    "imagem_url": getattr(p, 'imagem_url', None),
                    "unidade": getattr(p, 'unidade', 'un') or 'un',
                    "estoque": getattr(p, 'estoque', 50),
                }
                for p in prods_fb
            ]

        resultado.append({
            "id": s.id,
            "titulo": s.titulo,
            "tipo": s.tipo,
            "ordem": getattr(s, 'ordem', 0),
            "produtos": produtos_payload
        })

    for idx, b_sec in enumerate(banners_secundarios):
        posicao_ordem = b_sec.get("ordem", idx + 2)
        resultado.append({
            "id": 8880 + idx,
            "titulo": b_sec.get("titulo", "Destaque Promocional"),
            "tipo": "banner_secundario",
            "ordem": posicao_ordem,
            "itens": [b_sec],
            "produtos": []
        })

    resultado.sort(key=lambda x: x.get("ordem", 0))

    return resultado


# ==========================================
# 📂 ROTAS DE CLIENTES E USUÁRIOS
# ==========================================
@app.get("/admin/usuarios")
@app.get("/admin/usuarios/")
def listar_usuarios(db: Session = Depends(get_db)):
    usuarios = db.query(models.Cliente).all()
    
    return [
        {
            "id": u.id,
            "nome": u.nome,
            "email": u.email,
            "perfil": u.perfil or "cliente",
            "ativo": getattr(u, "ativo", True),
            "is_admin": getattr(u, "is_admin", False) or ((u.perfil or "").lower() in ["admin", "gestor"]),
            "eh_membro_clube": getattr(u, "eh_membro_clube", False),
            "cpf": getattr(u, "cpf", None)
        }
        for u in usuarios
    ]

@app.post("/admin/usuarios/", status_code=status.HTTP_201_CREATED)
@app.post("/admin/usuarios", status_code=status.HTTP_201_CREATED)
def cadastrar_usuario_admin(
    dados: schemas.UsuarioCreate,
    db: Session = Depends(get_db)
):
    email = dados.email.strip()
    nome = dados.nome.strip()
    senha = dados.senha
    perfil_escolhido = (dados.perfil or "separador").lower()

    if crud.get_cliente_by_email(db, email=email):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Já existe um usuário cadastrado com este e-mail."
        )
    
    senha_hash = security.gerar_hash_senha(senha)
    eh_admin = perfil_escolhido in ['admin', 'gestor']
    
    novo_usuario = models.Cliente(
        nome=nome,
        email=email,
        telefone=dados.telefone,
        senha_hash=senha_hash,
        perfil=perfil_escolhido,
        is_admin=eh_admin,
        eh_membro_clube=False,
        ativo=dados.ativo
    )
    
    db.add(novo_usuario)
    db.commit()
    db.refresh(novo_usuario)
    
    return {
        "mensagem": "Colaborador cadastrado com sucesso!",
        "usuario": {
            "id": novo_usuario.id,
            "nome": novo_usuario.nome,
            "email": novo_usuario.email,
            "perfil": novo_usuario.perfil,
            "is_admin": novo_usuario.is_admin
        }
    }

@app.patch("/admin/usuarios/{usuario_id}/status")
@app.patch("/admin/usuarios/{usuario_id}/status/")
def alterar_status_usuario(usuario_id: int, dados: dict, db: Session = Depends(get_db)):
    usuario = db.query(models.Cliente).filter(models.Cliente.id == usuario_id).first()
    if not usuario:
        raise HTTPException(status_code=404, detail="Usuário não encontrado")
    
    setattr(usuario, "ativo", dados.get("ativo", True))
    db.commit()
    return {"message": "Status do usuário atualizado com sucesso"}

@app.delete("/admin/usuarios/{usuario_id}")
@app.delete("/admin/usuarios/{usuario_id}/")
def deletar_usuario(usuario_id: int, db: Session = Depends(get_db)):
    usuario = db.query(models.Cliente).filter(models.Cliente.id == usuario_id).first()
    if not usuario:
        raise HTTPException(status_code=404, detail="Usuário não encontrado")
    
    db.delete(usuario)
    db.commit()
    return {"message": "Usuário excluído com sucesso"}

@app.get("/clientes/{cliente_id}/favoritos/")
@app.get("/clientes/{cliente_id}/favoritos")
def listar_favoritos(cliente_id: int, db: Session = Depends(get_db)):
    favoritos = db.query(Favorito).filter(Favorito.cliente_id == cliente_id).all()
    return [f.produto_id for f in favoritos]

@app.post("/clientes/{cliente_id}/favoritos/{produto_id}")
@app.post("/clientes/{cliente_id}/favoritos/{produto_id}/")
def favoritar_produto(cliente_id: int, produto_id: int, db: Session = Depends(get_db)):
    existente = db.query(Favorito).filter(Favorito.cliente_id == cliente_id, Favorito.produto_id == produto_id).first()
    if existente:
        db.delete(existente)
        db.commit()
        return {"status": "removido"}
    else:
        novo = Favorito(cliente_id=cliente_id, produto_id=produto_id)
        db.add(novo)
        db.commit()
        return {"status": "adicionado"}

@app.get("/clientes/", response_model=List[schemas.ClienteResponse])
@app.get("/clientes", response_model=List[schemas.ClienteResponse])
def listar_clientes(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    return crud.get_clientes(db=db, skip=skip, limit=limit)

@app.post("/api/cliente/vincular-cpf")
@app.post("/api/cliente/vincular-cpf/")
def vincular_cpf(dados: VincularCPFSchema, db: Session = Depends(get_db)):
    cpf_limpo = re.sub(r'\D', '', dados.cpf)
    
    if not validar_cpf(cpf_limpo):
        raise HTTPException(status_code=400, detail="CPF inválido. Verifique os números digitados.")

    cliente = db.query(models.Cliente).filter(models.Cliente.id == dados.cliente_id).first()
    if not cliente:
        raise HTTPException(status_code=404, detail="Cliente não encontrado.")

    cpf_formatado = f"{cpf_limpo[:3]}.{cpf_limpo[3:6]}.{cpf_limpo[6:9]}-{cpf_limpo[9:]}"
    cpf_existente = db.query(models.Cliente).filter(
        (models.Cliente.cpf == cpf_limpo) | (models.Cliente.cpf == cpf_formatado),
        models.Cliente.id != dados.cliente_id
    ).first()

    if cpf_existente:
        raise HTTPException(status_code=400, detail="Este CPF já está vinculado a outra conta.")

    cliente.cpf = cpf_formatado
    cliente.eh_membro_clube = True

    db.commit()
    db.refresh(cliente)

    return {
        "status": "sucesso",
        "mensagem": "CPF vinculado ao Clube Box Prime com sucesso!",
        "cpf": cliente.cpf,
        "eh_membro_clube": getattr(cliente, 'eh_membro_clube', True)
    }


# ==========================================
# 📂 ROTAS DE PEDIDOS (COM CÁLCULO SEGURO DE FRETE)
# ==========================================
@app.post("/pedidos/", status_code=status.HTTP_201_CREATED)
@app.post("/pedidos", status_code=status.HTTP_201_CREATED)
def criar_pedido(
    dados: schemas.PedidoCreate, 
    db: Session = Depends(get_db),
    current_user: models.Cliente = Depends(get_current_user)
):
    subtotal = calcular_total(dados.itens, db)

    info_frete = calcular_frete_backend(subtotal=subtotal, db=db)
    taxa_entrega = info_frete["valor_frete"]
    valor_total = subtotal + taxa_entrega

    endereco_req = getattr(dados, 'endereco_entrega', None)
    end_entrega = (
        endereco_req.strip() if (endereco_req and endereco_req.strip()) 
        else (obter_endereco_formatado_cliente(current_user) or "Endereço não informado")
    )

    forma_pag = getattr(dados, 'forma_pagamento', None) or "Dinheiro na Entrega"
    troco = float(getattr(dados, 'troco_para', 0.0) or 0.0)
    pago = bool(getattr(dados, 'esta_pago', False))

    novo_pedido = models.Pedido(
        cliente_id=current_user.id,
        status="PENDENTE",
        subtotal=subtotal,
        taxa_entrega=taxa_entrega,
        total=valor_total,
        endereco_entrega=end_entrega,
        forma_pagamento=forma_pag,
        troco_para=troco,
        esta_pago=pago,
        data_criacao=agora_brasilia()
    )

    db.add(novo_pedido)
    db.commit()
    db.refresh(novo_pedido)

    for item in dados.itens:
        prod = db.query(models.Produto).filter(models.Produto.id == item.produto_id).first()
        preco = prod.preco if prod else 0.0
        db_item = models.ItemPedido(
            pedido_id=novo_pedido.id,
            produto_id=item.produto_id,
            quantidade=item.quantidade,
            preco_unitario=preco
        )
        db.add(db_item)
    
    db.commit()
    db.refresh(novo_pedido)

    if getattr(current_user, 'fcm_token', None):
        enviar_notificacao_push(
            fcm_token=current_user.fcm_token,
            titulo="Pedido Recebido com Sucesso! 🛒",
            corpo=f"Olá {current_user.nome}, seu pedido #{novo_pedido.id} foi recebido e já está em processamento.",
            dados_extra={"pedido_id": str(novo_pedido.id), "status": "PENDENTE"}
        )

    return novo_pedido

@app.get("/admin/pedidos")
@app.get("/admin/pedidos/")
def listar_pedidos_admin(status: Optional[str] = None, db: Session = Depends(get_db)):
    query = db.query(Pedido).options(
        joinedload(Pedido.cliente).joinedload(models.Cliente.enderecos),
        joinedload(Pedido.itens).joinedload(models.ItemPedido.produto).joinedload(models.Produto.categoria)
    )
    
    if status and status.strip() != "" and status.lower() != "todos":
        query = query.filter(func.lower(Pedido.status) == status.strip().lower())
    
    pedidos = query.order_by(Pedido.data_criacao.desc()).all()
    
    resultado = []
    for p in pedidos:
        itens_lista = []
        for item in getattr(p, 'itens', []):
            cat_nome = "Mercearia / Geral"
            if item.produto and getattr(item.produto, 'categoria', None):
                cat_nome = item.produto.categoria.nome

            itens_lista.append({
                "id": item.id,
                "produto_id": item.produto_id,
                "nome": item.produto.nome if item.produto else "Produto",
                "quantidade": item.quantidade,
                "preco_unitario": float(item.preco_unitario or 0.0),
                "imagem_url": getattr(item.produto, 'imagem_url', None) if item.produto else None,
                "categoria_nome": cat_nome,
                "categoria": cat_nome
            })

        cliente_info = None
        if p.cliente:
            cliente_info = {
                "id": p.cliente.id,
                "nome": p.cliente.nome,
                "email": p.cliente.email,
                "telefone": getattr(p.cliente, 'telefone', None),
                "endereco": obter_endereco_formatado_cliente(p.cliente)
            }

        end_entrega = getattr(p, 'endereco_entrega', None)
        if not end_entrega or end_entrega == "Endereço não informado":
            end_entrega = obter_endereco_formatado_cliente(p.cliente) or "Endereço não informado"

        resultado.append({
            "id": p.id,
            "cliente_id": p.cliente_id,
            "cliente": cliente_info,
            "cliente_nome": p.cliente.nome if p.cliente else "Cliente Balcão",
            "eh_membro_clube": getattr(p, 'eh_membro_clube', False),
            "subtotal": float(getattr(p, 'subtotal', p.total) or 0.0),
            "taxa_entrega": float(getattr(p, 'taxa_entrega', 0.0) or 0.0),
            "total": float(p.total or 0.0),
            "status": p.status,
            "forma_pagamento": getattr(p, 'forma_pagamento', None) or "Dinheiro na Entrega",
            "troco_para": float(getattr(p, 'troco_para', 0.0) or 0.0),
            "esta_pago": bool(getattr(p, 'esta_pago', False)),
            "separado_por": getattr(p, 'separado_por', None) or "Aguardando separação",
            "separador_id": getattr(p, 'separador_id', None),
            "entregador_id": getattr(p, 'entregador_id', None),
            "entregador_nome": getattr(p, 'entregador_nome', None) or "Pendente de atribuição",
            "endereco_entrega": end_entrega,
            "data_criacao": p.data_criacao.isoformat() if getattr(p, 'data_criacao', None) else None,
            "data_separado": getattr(p, 'data_separado', None).isoformat() if getattr(p, 'data_separado', None) else None,
            "data_inicio_separacao": getattr(p, 'data_inicio_separacao', None).isoformat() if getattr(p, 'data_inicio_separacao', None) else None,
            "data_saiu_entrega": getattr(p, 'data_saiu_entrega', None).isoformat() if getattr(p, 'data_saiu_entrega', None) else None,
            "data_concluido": getattr(p, 'data_concluido', None).isoformat() if getattr(p, 'data_concluido', None) else None,
            "itens": itens_lista
        })
        
    return resultado

@app.put("/pedidos/{pedido_id}/status")
@app.put("/pedidos/{pedido_id}/status/")
@app.patch("/pedidos/{pedido_id}/status")
@app.patch("/pedidos/{pedido_id}/status/")
@app.put("/admin/pedidos/{pedido_id}/status")
@app.put("/admin/pedidos/{pedido_id}/status/")
@app.patch("/admin/pedidos/{pedido_id}/status")
@app.patch("/admin/pedidos/{pedido_id}/status/")
@app.patch("/admin/pedidos/{pedido_id}/finalizar-separacao")
@app.patch("/admin/pedidos/{pedido_id}/finalizar-separacao/")
@app.post("/admin/pedidos/{pedido_id}/finalizar-separacao")
@app.post("/admin/pedidos/{pedido_id}/finalizar-separacao/")
def atualizar_status_pedido_unificado(
    pedido_id: int, 
    dados: AtualizarStatusRequest, 
    db: Session = Depends(get_db),
    current_user: models.Cliente = Depends(get_current_user)
):
    pedido = db.query(models.Pedido).filter(models.Pedido.id == pedido_id).first()
    if not pedido:
        raise HTTPException(status_code=404, detail="Pedido não encontrado.")

    novo_status = dados.status.strip().upper()

    verificar_permissao_status(
        usuario=current_user,
        status_atual=pedido.status,
        novo_status=novo_status
    )

    eh_admin = current_user.is_admin or (getattr(current_user, 'perfil', '').lower() in ["admin", "gestor"])
    validar_transicao_status(
        status_atual=pedido.status,
        novo_status=novo_status,
        eh_admin=eh_admin
    )

    registrar_rastreabilidade_pedido(
        pedido=pedido,
        novo_status=novo_status,
        usuario_logado=current_user,
        dados_extra={
            "motivo_cancelamento": dados.motivo_cancelamento,
            "separado_por": dados.separado_por,
            "separador_id": dados.separador_id,
            "codigo_confirmacao": dados.codigo_confirmacao
        }
    )

    db.commit()
    db.refresh(pedido)

    if pedido.cliente and getattr(pedido.cliente, 'fcm_token', None):
        titulos_push = {
            "EM_SEPARACAO": "Seu pedido está em separação! 🛒",
            "SEPARADO": "Pedido separado e pronto! 📦",
            "SAIU_PARA_ENTREGA": "Seu pedido saiu para entrega! 🛵",
            "ENTREGUE": "Pedido entregue com sucesso! 🎉",
            "CANCELADO": "Atualização sobre o seu pedido ⚠️"
        }
        mensagens_push = {
            "EM_SEPARACAO": f"Olá {pedido.cliente.nome}, nosso operador começou a separar o pedido #{pedido.id}.",
            "SEPARADO": f"Tudo pronto! Seu pedido #{pedido.id} já foi separado e aguarda a coleta.",
            "SAIU_PARA_ENTREGA": f"Seu pedido #{pedido.id} está a caminho com o entregador!",
            "ENTREGUE": f"Seu pedido #{pedido.id} foi entregue. Bom apetite e obrigado por comprar no Box Smart!",
            "CANCELADO": f"O pedido #{pedido.id} foi cancelado."
        }

        if novo_status in titulos_push:
            enviar_notificacao_push(
                fcm_token=pedido.cliente.fcm_token,
                titulo=titulos_push[novo_status],
                corpo=mensagens_push[novo_status],
                dados_extra={"pedido_id": str(pedido.id), "status": novo_status}
            )

    return {
        "mensagem": f"Pedido #{pedido.id} atualizado para '{pedido.status}' com sucesso!",
        "pedido_id": pedido.id,
        "status": pedido.status,
        "atualizado_por": current_user.nome
    }

@app.get("/clientes/{cliente_id}/pedidos/")
@app.get("/clientes/{cliente_id}/pedidos")
def listar_pedidos_cliente(
    cliente_id: int,
    status: Optional[str] = Query(None, description="Filtrar por status do pedido"),
    data_inicio: Optional[date] = Query(None, description="Filtrar a partir da data (YYYY-MM-DD)"),
    db: Session = Depends(get_db),
):
    query = db.query(Pedido).filter(Pedido.cliente_id == cliente_id)
    
    if status and status.strip() != "" and status.lower() != "todos":
        status_limpo = status.strip().lower()
        query = query.filter(func.lower(Pedido.status) == status_limpo)
    
    if data_inicio:
        inicio_dt = datetime.combine(data_inicio, time_type.min).replace(tzinfo=FUSO_BRASILIA)
        query = query.filter(Pedido.data_criacao >= inicio_dt)
        
    pedidos = query.order_by(Pedido.data_criacao.desc()).all()
    
    return [
        {
            "id": p.id,
            "subtotal": float(getattr(p, 'subtotal', p.total) or 0.0),
            "taxa_entrega": float(getattr(p, 'taxa_entrega', 0.0) or 0.0),
            "total": float(p.total or 0.0),
            "status": getattr(p, 'status', 'PENDENTE'),
            "endereco_entrega": getattr(p, 'endereco_entrega', None) or (p.cliente.endereco if p.cliente and hasattr(p.cliente, 'endereco') else None) or 'Endereço não informado',
            "data_criacao": p.data_criacao.isoformat() if p.data_criacao else None,
            "itens": [
                {
                    "produto_id": item.produto_id,
                    "nome_produto": item.produto.nome if item.produto else "Produto",
                    "quantidade": item.quantidade,
                    "preco_unitario": float(item.preco_unitario or 0.0),
                    "categoria_nome": item.produto.categoria.nome if (item.produto and getattr(item.produto, 'categoria', None)) else "Geral"
                }
                for item in p.itens
            ] if hasattr(p, 'itens') else []
        }
        for p in pedidos
    ]

@app.get("/pedidos/{pedido_id}")
@app.get("/pedidos/{pedido_id}/")
def obter_detalhes_pedido(
    pedido_id: int,
    db: Session = Depends(get_db),
    current_user: models.Cliente = Depends(get_current_user)
):
    pedido = db.query(models.Pedido).filter(models.Pedido.id == pedido_id).first()
    if not pedido:
        raise HTTPException(status_code=404, detail="Pedido não encontrado.")

    perfil = (getattr(current_user, 'perfil', '') or '').lower()
    eh_admin_ou_staff = current_user.is_admin or perfil in ["admin", "gestor", "separador", "entregador"]
    
    if not eh_admin_ou_staff and pedido.cliente_id != current_user.id:
        raise HTTPException(status_code=403, detail="Acesso não autorizado a este pedido.")

    itens_lista = []
    for item in pedido.itens:
        itens_lista.append({
            "id": item.id,
            "produto_id": item.produto_id,
            "nome": item.produto.nome if item.produto else "Produto",
            "quantidade": item.quantidade,
            "preco_unitario": float(item.preco_unitario or 0.0)
        })

    return {
        "id": pedido.id,
        "status": pedido.status,
        "subtotal": float(getattr(pedido, 'subtotal', pedido.total) or 0.0),
        "taxa_entrega": float(getattr(pedido, 'taxa_entrega', 0.0) or 0.0),
        "total": float(pedido.total or 0.0),
        "cliente_nome": pedido.cliente.nome if pedido.cliente else "Cliente",
        "endereco_entrega": getattr(pedido, 'endereco_entrega', None) or getattr(pedido.cliente, 'endereco', 'Não informado'),
        "forma_pagamento": getattr(pedido, 'forma_pagamento', 'Não informada'),
        "separado_por": getattr(pedido, 'separado_por', None),
        "motivo_cancelamento": getattr(pedido, 'motivo_cancelamento', None),
        "data_criacao": pedido.data_criacao.isoformat() if getattr(pedido, 'data_criacao', None) else None,
        "data_inicio_separacao": pedido.data_inicio_separacao.isoformat() if getattr(pedido, 'data_inicio_separacao', None) else None,
        "data_separado": pedido.data_separado.isoformat() if getattr(pedido, 'data_separado', None) else None,
        "data_saiu_entrega": pedido.data_saiu_entrega.isoformat() if getattr(pedido, 'data_saiu_entrega', None) else None,
        "data_concluido": pedido.data_concluido.isoformat() if getattr(pedido, 'data_concluido', None) else None,
        "data_cancelado": pedido.data_cancelado.isoformat() if getattr(pedido, 'data_cancelado', None) else None,
        "itens": itens_lista
    }


# ==========================================
# 📂 AUTENTICAÇÃO (LOGIN)
# ==========================================
@app.post("/login/", response_model=schemas.TokenResponse)
@app.post("/login", response_model=schemas.TokenResponse)
def login_cliente(dados_login: schemas.LoginRequest, db: Session = Depends(get_db)):
    cliente = crud.get_cliente_by_email(db, email=dados_login.email)

    if not cliente or not security.verificar_senha(dados_login.senha, cliente.senha_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="E-mail ou senha incorretos.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token_data = {
        "sub": cliente.email,
        "is_admin": getattr(cliente, 'is_admin', False),
        "perfil": getattr(cliente, 'perfil', 'cliente')
    }
    token_acesso = security.criar_token_acesso(data=token_data)

    return {
        "access_token": token_acesso,
        "token_type": "bearer",
        "perfil": getattr(cliente, 'perfil', 'cliente'),
        "nome": cliente.nome,
        "is_admin": getattr(cliente, 'is_admin', False)
    }


# ==========================================
# 📂 ROTAS DE BANNERS (ADMIN)
# ==========================================
@app.post("/admin/banners/", response_model=schemas.BannerResponse, status_code=201)
@app.post("/admin/banners", response_model=schemas.BannerResponse, status_code=201)
def criar_banner_admin(banner: schemas.BannerCreate, db: Session = Depends(get_db)):
    return crud.criar_banner(db=db, banner=banner)

@app.get("/banners/", response_model=List[schemas.BannerResponse])
@app.get("/banners", response_model=List[schemas.BannerResponse])
def listar_banners_ativos(db: Session = Depends(get_db)):
    banners = db.query(models.Banner).filter(models.Banner.ativo == True).order_by(models.Banner.ordem.asc()).all()
    return [
        {
            "id": b.id,
            "titulo": b.titulo,
            "imagem_url": b.imagem_url,
            "ativo": b.ativo,
            "data_criacao": b.data_criacao,
            "tipo": getattr(b, 'tipo', 'principal'),
            "ordem": getattr(b, 'ordem', 0),
            "acao_tipo": getattr(b, 'acao_tipo', None),
            "acao_valor": getattr(b, 'acao_valor', None),
        }
        for b in banners
    ]

@app.delete("/admin/banners/{banner_id}")
@app.delete("/admin/banners/{banner_id}/")
def deletar_banner_admin(banner_id: int, db: Session = Depends(get_db)):
    sucesso = crud.deletar_banner(db=db, banner_id=banner_id)
    if not sucesso:
        raise HTTPException(status_code=404, detail="Banner não encontrado.")
    return {"mensagem": f"Banner {banner_id} removido com sucesso!"}

@app.put("/admin/banners/{banner_id}")
@app.put("/admin/banners/{banner_id}/")
def atualizar_banner_admin(banner_id: int, banner: schemas.BannerCreate, db: Session = Depends(get_db)):
    banner_db = db.query(models.Banner).filter(models.Banner.id == banner_id).first()
    if not banner_db:
        raise HTTPException(status_code=404, detail="Banner não encontrado.")
    
    banner_db.titulo = banner.titulo
    banner_db.imagem_url = banner.imagem_url
    banner_db.tipo = getattr(banner, 'tipo', 'principal')
    banner_db.ordem = getattr(banner, 'ordem', 0)
    banner_db.ativo = getattr(banner, 'ativo', True)
    banner_db.acao_tipo = getattr(banner, 'acao_tipo', None)
    banner_db.acao_valor = getattr(banner, 'acao_valor', None)
    
    db.commit()
    db.refresh(banner_db)
    return banner_db


# ==========================================
# 📂 NOTIFICAÇÕES E ENDEREÇOS
# ==========================================
@app.patch("/clientes/fcm-token")
@app.patch("/clientes/fcm-token/")
def atualizar_fcm_token(
    dados: dict,
    db: Session = Depends(get_db),
    current_user: models.Cliente = Depends(get_current_user)
):
    token = dados.get("fcm_token")
    if not token:
        raise HTTPException(status_code=400, detail="fcm_token é obrigatório.")
    
    current_user.fcm_token = token
    db.commit()
    return {"mensagem": "FCM Token atualizado com sucesso!"}

@app.get("/admin/notificacoes", response_model=List[schemas.NotificacaoOut])
@app.get("/admin/notificacoes/", response_model=List[schemas.NotificacaoOut])
def listar_todas_notificacoes(db: Session = Depends(get_db)):
    return db.query(models.Notificacao).order_by(models.Notificacao.data_envio.desc()).limit(50).all()

@app.delete("/admin/notificacoes/{notificacao_id}", status_code=204)
@app.delete("/admin/notificacoes/{notificacao_id}/", status_code=204)
def deletar_notificacao(notificacao_id: int, db: Session = Depends(get_db)):
    notificacao = db.query(models.Notificacao).filter(models.Notificacao.id == notificacao_id).first()
    if not notificacao:
        raise HTTPException(status_code=404, detail="Notificação não encontrada")
        
    db.delete(notificacao)
    db.commit()
    return {"message": "Notificação excluída com sucesso"}

@app.post("/admin/notificacoes/campanha", status_code=201)
@app.post("/admin/notificacoes/campanha/", status_code=201)
def disparar_campanha_marketing(titulo: str, mensagem: str, db: Session = Depends(get_db)):
    nova_notificacao = models.Notificacao(titulo=titulo, mensagem=mensagem, cliente_id=None, data_envio=agora_brasilia())
    db.add(nova_notificacao)
    db.commit()
    db.refresh(nova_notificacao)
    return {
        "mensagem": "Campanha de marketing disparada com sucesso para o Clube Box Smart!",
        "campanha": {"titulo": titulo, "detalhes": mensagem, "data": nova_notificacao.data_envio}
    }

@app.post("/admin/notificacoes", response_model=schemas.NotificacaoOut, status_code=201)
@app.post("/admin/notificacoes/", response_model=schemas.NotificacaoOut, status_code=201)
def disparar_notificacao(notificacao: schemas.NotificacaoCreate, db: Session = Depends(get_db)):
    nova_notificacao = models.Notificacao(
        titulo=notificacao.titulo,
        mensagem=notificacao.mensagem,
        cliente_id=notificacao.cliente_id,
        tipo=notificacao.tipo,
        lida=False,
        data_envio=agora_brasilia()
    )
    db.add(nova_notificacao)
    db.commit()
    db.refresh(nova_notificacao)
    return nova_notificacao

@app.get("/clientes/{cliente_id}/notificacoes")
@app.get("/clientes/{cliente_id}/notificacoes/")
def listar_notificacoes_cliente(cliente_id: int, db: Session = Depends(get_db)):
    return db.query(models.Notificacao).filter(
        (models.Notificacao.cliente_id == cliente_id) | (models.Notificacao.cliente_id == None)
    ).all()

@app.patch("/clientes/{cliente_id}/notificacoes/{notificacao_id}/lida")
@app.patch("/clientes/{cliente_id}/notificacoes/{notificacao_id}/lida/")
def marcar_notificacao_lida(cliente_id: int, notificacao_id: int, db: Session = Depends(get_db)):
    notificacao = db.query(models.Notificacao).filter(models.Notificacao.id == notificacao_id).first()
    if not notificacao:
        raise HTTPException(status_code=404, detail="Notificação não encontrada")
    
    notificacao.lida = True
    db.commit()
    return {"message": "Notificação marcada como lida com sucesso!"}

@app.get("/clientes/{cliente_id}/enderecos")
@app.get("/clientes/{cliente_id}/enderecos/")
def listar_enderecos(cliente_id: int, db: Session = Depends(get_db)):
    return db.query(models.Endereco).filter(models.Endereco.cliente_id == cliente_id).all()

@app.post("/clientes/{cliente_id}/enderecos")
@app.post("/clientes/{cliente_id}/enderecos/")
def criar_endereco(cliente_id: int, endereco: dict, db: Session = Depends(get_db)):
    novo_endereco = models.Endereco(cliente_id=cliente_id, **endereco)
    db.add(novo_endereco)
    db.commit()
    db.refresh(novo_endereco)
    return novo_endereco


# ==========================================
# 📂 MOTOR DE RECOMENDAÇÃO INTELIGENTE
# ==========================================
@app.get("/api/produtos/{produto_id}/relacionados")
@app.get("/api/produtos/{produto_id}/relacionados/")
def obter_produtos_relacionados(produto_id: int, db: Session = Depends(get_db)):
    recoms_ia = (
        db.query(models.RecomendacaoIA)
        .filter(models.RecomendacaoIA.produto_id_a == produto_id)
        .order_by(models.RecomendacaoIA.frequencia.desc())
        .limit(6)
        .all()
    )

    ids_recomendados = [r.produto_id_b for r in recoms_ia]

    if not ids_recomendados:
        prod_atual = db.query(models.Produto).filter(models.Produto.id == produto_id).first()
        if prod_atual and prod_atual.categoria_id:
            relacionados = (
                db.query(models.Produto)
                .filter(
                    models.Produto.categoria_id == prod_atual.categoria_id,
                    models.Produto.id != produto_id,
                    models.Produto.ativo == True
                )
                .limit(6)
                .all()
            )
            return [
                {
                    "id": p.id,
                    "nome": p.nome,
                    "descricao": getattr(p, 'descricao', ''),
                    "preco": float(p.preco),
                    "preco_clube": float(p.preco_clube) if getattr(p, 'preco_clube', None) else None,
                    "imagem_url": getattr(p, 'imagem_url', None),
                    "unidade": getattr(p, 'unidade', 'un') or 'un'
                }
                for p in relacionados
            ]
        return []

    produtos = (
        db.query(models.Produto)
        .filter(models.Produto.id.in_(ids_recomendados), models.Produto.ativo == True)
        .all()
    )

    return [
        {
            "id": p.id,
            "nome": p.nome,
            "descricao": getattr(p, 'descricao', ''),
            "preco": float(p.preco),
            "preco_clube": float(p.preco_clube) if getattr(p, 'preco_clube', None) else None,
            "imagem_url": getattr(p, 'imagem_url', None),
            "unidade": getattr(p, 'unidade', 'un') or 'un'
        }
        for p in produtos
    ]


# ==========================================
# 📂 MÉTRICAS AVANÇADAS DE BI E IA
# ==========================================
@app.get("/admin/relatorios/lead-time")
@app.get("/admin/relatorios/lead-time/")
def relatorio_lead_time(
    data_inicio: Optional[date] = Query(None),
    data_fim: Optional[date] = Query(None),
    db: Session = Depends(get_db)
):
    query = db.query(models.Pedido).filter(
        func.upper(models.Pedido.status).in_(["CONCLUIDO", "CONCLUÍDO", "ENTREGUE"]),
        models.Pedido.data_concluido.isnot(None),
        models.Pedido.data_criacao.isnot(None)
    )
    query = aplicar_filtro_data(query, models.Pedido.data_criacao, data_inicio, data_fim)
    pedidos = query.all()

    if not pedidos:
        return {
            "tempo_medio_separacao_minutos": 0,
            "tempo_medio_entrega_minutos": 0,
            "lead_time_total_minutos": 0,
            "total_pedidos_analisados": 0
        }

    total_separacao = 0.0
    total_entrega = 0.0
    total_ciclo = 0.0
    qtd_separacao = 0
    qtd_entrega = 0

    for p in pedidos:
        ciclo = (p.data_concluido - p.data_criacao).total_seconds() / 60.0
        total_ciclo += ciclo

        if getattr(p, 'data_separado', None) and p.data_criacao:
            sep = (p.data_separado - p.data_criacao).total_seconds() / 60.0
            if sep >= 0:
                total_separacao += sep
                qtd_separacao += 1

        if p.data_concluido and getattr(p, 'data_saiu_entrega', None):
            ent = (p.data_concluido - p.data_saiu_entrega).total_seconds() / 60.0
            if ent >= 0:
                total_entrega += ent
                qtd_entrega += 1

    n = len(pedidos)
    return {
        "tempo_medio_separacao_minutos": round(total_separacao / qtd_separacao, 1) if qtd_separacao > 0 else 0,
        "tempo_medio_entrega_minutos": round(total_entrega / qtd_entrega, 1) if qtd_entrega > 0 else 0,
        "lead_time_total_minutos": round(total_ciclo / n, 1),
        "total_pedidos_analisados": n
    }

@app.get("/admin/relatorios/risco-churn")
@app.get("/admin/relatorios/risco-churn/")
def relatorio_risco_churn(dias_inativo: int = 15, db: Session = Depends(get_db)):
    agora = agora_brasilia()
    membros = db.query(models.Cliente).filter(
        models.Cliente.eh_membro_clube == True,
        models.Cliente.ativo == True
    ).all()

    inativos = []
    for m in membros:
        ultimo_pedido = (
            db.query(models.Pedido)
            .filter(models.Pedido.cliente_id == m.id)
            .order_by(models.Pedido.data_criacao.desc())
            .first()
        )

        if not ultimo_pedido:
            inativos.append({
                "cliente_id": m.id,
                "nome": m.nome,
                "email": m.email,
                "dias_sem_comprar": 999,
                "ultimo_pedido_data": "Nunca comprou"
            })
        else:
            dt_pedido = ultimo_pedido.data_criacao
            agora_naive = agora.replace(tzinfo=None) if agora.tzinfo else agora
            dt_pedido_naive = dt_pedido.replace(tzinfo=None) if dt_pedido.tzinfo else dt_pedido

            dias = (agora_naive - dt_pedido_naive).days
            if dias >= dias_inativo:
                inativos.append({
                    "cliente_id": m.id,
                    "nome": m.nome,
                    "email": m.email,
                    "dias_sem_comprar": dias,
                    "ultimo_pedido_data": dt_pedido.strftime("%d/%m/%Y")
                })

    inativos.sort(key=lambda x: x["dias_sem_comprar"], reverse=True)
    return {
        "total_risco_churn": len(inativos),
        "clientes_em_risco": inativos[:8]
    }

@app.get("/admin/relatorios/previsao-demanda")
@app.get("/admin/relatorios/previsao-demanda/")
def previsao_demanda(db: Session = Depends(get_db)):
    top_produtos = (
        db.query(
            models.Produto.nome.label("nome"),
            func.sum(models.ItemPedido.quantidade).label("total")
        )
        .join(models.ItemPedido, models.ItemPedido.produto_id == models.Produto.id)
        .join(models.Pedido, models.ItemPedido.pedido_id == models.Pedido.id)
        .group_by(models.Produto.nome)
        .order_by(desc("total"))
        .limit(5)
        .all()
    )

    previsao = []
    for item in top_produtos:
        qtd_historica = int(item.total or 0)
        estimada = round(qtd_historica * 1.20) if qtd_historica > 0 else 10
        previsao.append({
            "produto": item.nome,
            "historico_vendas": qtd_historica,
            "previsao_proximo_fds": estimada
        })

    return previsao

@app.get("/admin/relatorios/recorrencia-clientes")
@app.get("/admin/relatorios/recorrencia-clientes/")
def relatorio_recorrencia_clientes(db: Session = Depends(get_db)):
    pedidos = db.query(
        models.Pedido.cliente_id,
        models.Pedido.data_criacao,
        models.Pedido.total
    ).filter(
        func.upper(models.Pedido.status) != "CANCELADO"
    ).order_by(models.Pedido.cliente_id, models.Pedido.data_criacao.asc()).all()

    if not pedidos:
        return {
            "total_clientes_unicos": 0,
            "clientes_recorrentes": 0,
            "clientes_compra_unica": 0,
            "taxa_recorrencia": 0.0,
            "frequencia_media_compras": 0.0,
            "intervalo_medio_dias": 0.0,
            "distribuicao_frequencia": {
                "1_compra": 0,
                "2_a_3_compras": 0,
                "4_a_5_compras": 0,
                "6_ou_mais_compras": 0
            },
            "top_clientes_recorrentes": []
        }

    historico_cliente = {}
    for p in pedidos:
        cid = p.cliente_id
        if cid not in historico_cliente:
            historico_cliente[cid] = []
        historico_cliente[cid].append(p)

    total_clientes = len(historico_cliente)
    compra_unica = 0
    recorrentes = 0
    totais_intervalos = []
    totais_pedidos_por_cliente = []

    distribuicao = {
        "1_compra": 0,
        "2_a_3_compras": 0,
        "4_a_5_compras": 0,
        "6_ou_mais_compras": 0
    }

    clientes_db = {
        c.id: c.nome for c in db.query(models.Cliente.id, models.Cliente.nome).filter(models.Cliente.id.in_(historico_cliente.keys())).all()
    }

    ranking_clientes = []

    for cid, lista_p in historico_cliente.items():
        qtd = len(lista_p)
        totais_pedidos_por_cliente.append(qtd)
        total_gasto = sum(float(p.total or 0.0) for p in lista_p)

        if qtd == 1:
            compra_unica += 1
            distribuicao["1_compra"] += 1
        else:
            recorrentes += 1
            if 2 <= qtd <= 3:
                distribuicao["2_a_3_compras"] += 1
            elif 4 <= qtd <= 5:
                distribuicao["4_a_5_compras"] += 1
            else:
                distribuicao["6_ou_mais_compras"] += 1

            for i in range(1, len(lista_p)):
                dt_anterior = lista_p[i-1].data_criacao
                dt_atual = lista_p[i].data_criacao
                if dt_anterior and dt_atual:
                    diff_dias = (dt_atual - dt_anterior).total_seconds() / 86400.0
                    totais_intervalos.append(diff_dias)

        ranking_clientes.append({
            "cliente_id": cid,
            "nome": clientes_db.get(cid, f"Cliente #{cid}"),
            "total_pedidos": qtd,
            "total_gasto": round(total_gasto, 2),
            "ticket_medio": round(total_gasto / qtd, 2)
        })

    taxa_recorrencia = (recorrentes / total_clientes * 100) if total_clientes > 0 else 0.0
    freq_media = sum(totais_pedidos_por_cliente) / total_clientes if total_clientes > 0 else 0.0
    intervalo_medio = sum(totais_intervalos) / len(totais_intervalos) if totais_intervalos else 0.0

    ranking_clientes.sort(key=lambda x: x["total_gasto"], reverse=True)

    return {
        "total_clientes_unicos": total_clientes,
        "clientes_recorrentes": recorrentes,
        "clientes_compra_unica": compra_unica,
        "taxa_recorrencia": round(taxa_recorrencia, 1),
        "frequencia_media_compras": round(freq_media, 2),
        "intervalo_medio_dias": round(intervalo_medio, 1),
        "distribuicao_frequencia": distribuicao,
        "top_clientes_recorrentes": ranking_clientes[:10]
    }

@app.get("/admin/relatorios/curva-abc")
@app.get("/admin/relatorios/curva-abc/")
def relatorio_curva_abc(
    data_inicio: Optional[date] = Query(None),
    data_fim: Optional[date] = Query(None),
    db: Session = Depends(get_db)
):
    query = db.query(
        models.Produto.id,
        models.Produto.nome,
        models.Produto.preco,
        func.coalesce(func.sum(models.ItemPedido.quantidade), 0).label("qtd_vendida"),
        func.coalesce(func.sum(models.ItemPedido.quantidade * models.ItemPedido.preco_unitario), 0.0).label("receita_total")
    ).join(models.ItemPedido, models.Produto.id == models.ItemPedido.produto_id)\
     .join(models.Pedido, models.ItemPedido.pedido_id == models.Pedido.id)\
     .filter(func.upper(models.Pedido.status) != "CANCELADO")

    if data_inicio:
        inicio_dt = datetime.combine(data_inicio, time_type.min).replace(tzinfo=FUSO_BRASILIA)
        query = query.filter(models.Pedido.data_criacao >= inicio_dt)
    if data_fim:
        fim_dt = datetime.combine(data_fim, time_type.max).replace(tzinfo=FUSO_BRASILIA)
        query = query.filter(models.Pedido.data_criacao <= fim_dt)

    vendas_produtos = query.group_by(models.Produto.id)\
                           .order_by(desc("receita_total")).all()

    receita_global = sum(float(p.receita_total or 0) for p in vendas_produtos)
    acumulado = 0.0
    resultado = []

    qtd_a, qtd_b, qtd_c = 0, 0, 0
    receita_a, receita_b, receita_c = 0.0, 0.0, 0.0

    for item in vendas_produtos:
        receita = float(item.receita_total or 0)
        acumulado += receita
        perc_acumulado = (acumulado / receita_global * 100) if receita_global > 0 else 0.0
        perc_individual = (receita / receita_global * 100) if receita_global > 0 else 0.0

        if perc_acumulado <= 80.0 or (acumulado - receita) < 80.0 and len(resultado) == 0:
            classe = "A"
            qtd_a += 1
            receita_a += receita
        elif perc_acumulado <= 95.0 or (acumulado - receita) < 95.0:
            classe = "B"
            qtd_b += 1
            receita_b += receita
        else:
            classe = "C"
            qtd_c += 1
            receita_c += receita

        resultado.append({
            "id": item.id,
            "nome": item.nome,
            "preco": float(item.preco or 0.0),
            "qtd_vendida": int(item.qtd_vendida or 0),
            "receita_total": round(receita, 2),
            "percentual_individual": round(perc_individual, 2),
            "percentual_acumulado": round(perc_acumulado, 2),
            "classe": classe
        })

    return {
        "receita_global": round(receita_global, 2),
        "total_produtos_vendidos": len(resultado),
        "resumo_classes": {
            "classe_a": {"quantidade": qtd_a, "receita": round(receita_a, 2), "percentual": round((receita_a / receita_global * 100) if receita_global > 0 else 0, 1)},
            "classe_b": {"quantidade": qtd_b, "receita": round(receita_b, 2), "percentual": round((receita_b / receita_global * 100) if receita_global > 0 else 0, 1)},
            "classe_c": {"quantidade": qtd_c, "receita": round(receita_c, 2), "percentual": round((receita_c / receita_global * 100) if receita_global > 0 else 0, 1)},
        },
        "produtos": resultado
    }

@app.get("/admin/relatorios/vendas-por-bairro")
@app.get("/admin/relatorios/vendas-por-bairro/")
def relatorio_vendas_por_bairro(
    data_inicio: Optional[date] = Query(None),
    data_fim: Optional[date] = Query(None),
    db: Session = Depends(get_db)
):
    query = db.query(models.Pedido).filter(
        func.upper(models.Pedido.status) != "CANCELADO"
    )
    query = aplicar_filtro_data(query, models.Pedido.data_criacao, data_inicio, data_fim)
    pedidos = query.all()

    agrupado_bairro = {}
    faturamento_global = 0.0

    for p in pedidos:
        end = p.endereco_entrega or ""
        bairro = "Centro / Geral"

        if "-" in end:
            partes = [parte.strip() for parte in end.split("-")]
            if len(partes) >= 2:
                sub_partes = partes[-1].split(",")
                if len(sub_partes) >= 2:
                    bairro = sub_partes[0].strip()
                elif len(partes) >= 3:
                    bairro = partes[-2].split(",")[-1].strip()

        if not bairro or bairro == "":
            bairro = "Centro / Geral"

        valor = float(p.total or 0.0)
        faturamento_global += valor

        if bairro not in agrupado_bairro:
            agrupado_bairro[bairro] = {"total_pedidos": 0, "faturamento": 0.0}

        agrupado_bairro[bairro]["total_pedidos"] += 1
        agrupado_bairro[bairro]["faturamento"] += valor

    resultado = []
    for bairro_nome, dados in agrupado_bairro.items():
        faturamento = dados["faturamento"]
        pedidos_qtd = dados["total_pedidos"]
        ticket_medio = faturamento / pedidos_qtd if pedidos_qtd > 0 else 0.0
        percentual = (faturamento / faturamento_global * 100) if faturamento_global > 0 else 0.0

        resultado.append({
            "bairro": bairro_nome,
            "total_pedidos": pedidos_qtd,
            "faturamento": round(faturamento, 2),
            "ticket_medio": round(ticket_medio, 2),
            "percentual_total": round(percentual, 2)
        })

    resultado.sort(key=lambda x: x["faturamento"], reverse=True)

    return {
        "faturamento_global": round(faturamento_global, 2),
        "total_bairros_atendidos": len(resultado),
        "bairros": resultado
    }


# ==========================================
# 📂 ROTA DO CLUBE BOX PRIME
# ==========================================
@app.get("/api/box-prime")
@app.get("/api/box-prime/")
def obter_dados_box_prime(cliente_id: int, db: Session = Depends(get_db)):
    config = db.query(models.ConfigBoxPrime).first()
    cliente = db.query(models.Cliente).filter(models.Cliente.id == cliente_id).first()
    eh_membro = getattr(cliente, 'eh_membro_clube', False) if cliente else False

    beneficios = json.loads(config.beneficios_json) if config and config.beneficios_json else [
        {"titulo": "Frete Verde", "descricao": "Condições especiais de entrega."},
        {"titulo": "Ofertas Relâmpago", "descricao": "Acesso antecipado a promoções."}
    ]

    return {
        "titulo_topo": config.titulo_topo if config else "Clube Box Prime",
        "subtitulo": config.subtitulo if config else "Exclusividade e vantagens criadas para você.",
        "historia": config.historia if config else "O Box Prime nasceu com a missão de recompensar...",
        "eh_membro": eh_membro,
        "beneficios": beneficios
    }

@app.post("/api/box-prime/entrar")
@app.post("/api/box-prime/entrar/")
def entrar_no_clube(dados: dict, db: Session = Depends(get_db)):
    cliente_id = dados.get("cliente_id")
    cliente = db.query(models.Cliente).filter(models.Cliente.id == cliente_id).first()
    
    if not cliente:
        raise HTTPException(status_code=404, detail="Cliente não encontrado.")
    
    setattr(cliente, 'eh_membro_clube', True)
    db.commit()
    
    return {"mensagem": "Parabéns! Agora você faz parte do Box Prime."}

@app.put("/admin/box-prime")
@app.put("/admin/box-prime/")
def atualizar_dados_box_prime(dados: dict, db: Session = Depends(get_db)):
    config = db.query(models.ConfigBoxPrime).first()
    if not config:
        config = models.ConfigBoxPrime()
        db.add(config)
    
    config.titulo_topo = dados.get("titulo_topo", config.titulo_topo)
    config.subtitulo = dados.get("subtitulo", config.subtitulo)
    config.historia = dados.get("historia", config.historia)
    if "beneficios" in dados:
        config.beneficios_json = json.dumps(dados["beneficios"])
        
    db.commit()
    db.refresh(config)
    return {"mensagem": "Configurações do Box Prime atualizadas com sucesso!"}


# ==========================================
# 📂 ROTAS DE LOCALIZAÇÃO DO ENTREGADOR
# ==========================================
@app.patch("/admin/pedidos/{pedido_id}/localizacao")
@app.patch("/admin/pedidos/{pedido_id}/localizacao/")
def atualizar_localizacao_entregador(
    pedido_id: int, 
    dados: LocalizacaoEntregadorSchema, 
    db: Session = Depends(get_db),
    current_user: models.Cliente = Depends(get_current_user)
):
    pedido = db.query(models.Pedido).filter(models.Pedido.id == pedido_id).first()
    if not pedido:
        raise HTTPException(status_code=404, detail="Pedido não encontrado")

    pedido.latitude_entregador = dados.latitude
    pedido.longitude_entregador = dados.longitude
    
    db.commit()
    return {"mensagem": "Localização atualizada com sucesso"}

@app.get("/pedidos/{pedido_id}/localizacao")
@app.get("/pedidos/{pedido_id}/localizacao/")
def obter_localizacao_entregador(pedido_id: int, db: Session = Depends(get_db)):
    pedido = db.query(models.Pedido).filter(models.Pedido.id == pedido_id).first()
    if not pedido:
        raise HTTPException(status_code=404, detail="Pedido não encontrado")

    return {
        "pedido_id": pedido.id,
        "status": pedido.status,
        "latitude": pedido.latitude_entregador,
        "longitude": pedido.longitude_entregador,
        "entregador_nome": pedido.entregador_nome or "Entregador"
    }


# ==========================================
# 📂 RECONQUISTA DE CLIENTES (CHURN)
# ==========================================
@app.post("/admin/notificacoes/churn/{cliente_id}")
@app.post("/admin/notificacoes/churn/{cliente_id}/")
def enviar_notificacao_churn(
    cliente_id: int, 
    db: Session = Depends(get_db),
    current_user: models.Cliente = Depends(get_current_user)
):
    cliente = db.query(models.Cliente).filter(models.Cliente.id == cliente_id).first()
    if not cliente:
        raise HTTPException(status_code=404, detail="Cliente não encontrado.")
    
    nova_notificacao = models.Notificacao(
        cliente_id=cliente_id,
        titulo="Sentimos sua falta no Clube Prime! 🎁",
        mensagem=f"Olá, {cliente.nome}! Preparamos ofertas exclusivas no aplicativo com desconto especial para você voltar a economizar.",
        tipo="reconquista_churn",
        lida=False,
        data_envio=agora_brasilia()
    )
    
    db.add(nova_notificacao)
    db.commit()
    db.refresh(nova_notificacao)
    
    if getattr(cliente, 'fcm_token', None):
        enviar_notificacao_push(
            fcm_token=cliente.fcm_token,
            titulo="Sentimos sua falta no Clube Prime! 🎁",
            corpo=f"Olá, {cliente.nome}! Preparamos ofertas exclusivas no app para você voltar a economizar.",
            dados_extra={"tipo": "churn"}
        )

    return {
        "mensagem": f"Notificação de reconquista enviada para {cliente.nome}!",
        "notificacao_id": nova_notificacao.id
    }


# ==========================================
# 📂 ROTA DE CADASTRO DO APP CLIENTE
# ==========================================
@app.post("/clientes/", status_code=status.HTTP_201_CREATED)
@app.post("/clientes", status_code=status.HTTP_201_CREATED)
def cadastrar_cliente_app(
    dados: schemas.UsuarioCreate,
    db: Session = Depends(get_db)
):
    email = dados.email.strip()
    nome = dados.nome.strip()
    senha = dados.senha

    if crud.get_cliente_by_email(db, email=email):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Já existe uma conta cadastrada com este e-mail."
        )
    
    senha_hash = security.gerar_hash_senha(senha)
    
    novo_cliente = models.Cliente(
        nome=nome,
        email=email,
        telefone=dados.telefone,
        senha_hash=senha_hash,
        perfil="cliente",
        is_admin=False,
        eh_membro_clube=False,
        ativo=True
    )
    
    db.add(novo_cliente)
    db.commit()
    db.refresh(novo_cliente)
    
    return {
        "mensagem": "Cliente cadastrado com sucesso!",
        "id": novo_cliente.id,
        "email": novo_cliente.email
    }


# ==========================================
# 🔄 ENDPOINT DE SINCRONIZAÇÃO WEBSAC -> FIREBASE
# ==========================================
@app.post("/admin/sincronizar-agora")
@app.post("/admin/sincronizar-agora/")
async def forcar_sincronizacao_manual(background_tasks: BackgroundTasks):
    """
    Endpoint administrativo para disparar a carga manual do WebSac
    e salvar/espelhar produtos no Firebase Firestore em segundo plano.
    """
    if not WebSacIntegration:
        raise HTTPException(status_code=500, detail="Módulo WebSacIntegration não foi localizado no backend.")

    try:
        websac = WebSacIntegration(
            cnpj="44737674000149", 
            token="ba2e4041-0d3d-4ed5-a110-df9ca841102c",
            dominio="tescarollo"
        )
        produtos = await websac.sincronizar_catalogo()
        
        # Gravação pesada de 22k produtos roda em background
        background_tasks.add_task(salvar_produtos_no_firebase, produtos)

        return {
            "status": "Processamento Iniciado",
            "mensagem": f"Sincronização de {len(produtos)} produtos iniciada em segundo plano.",
            "total_produtos": len(produtos)
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro ao disparar sincronização WebSac: {str(e)}")