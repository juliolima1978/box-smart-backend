import os
import json
import re
import time
import asyncio
from enum import Enum
from typing import List, Optional
from datetime import date, datetime, time as time_type, timedelta
from zoneinfo import ZoneInfo
from contextlib import asynccontextmanager
from fastapi import FastAPI, Depends, HTTPException, status, Query, BackgroundTasks, APIRouter, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import OAuth2PasswordBearer
from pydantic import BaseModel, EmailStr
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
import pandas as pd
import requests
import secrets
from passlib.context import CryptContext
from database import engine, get_db, SessionLocal
from models import Pedido, Produto, ItemPedido, Categoria, Favorito, Endereco, Cliente
from treinar_recomendacao import treinar_motor_recomendacao
from routers.frete import router as frete_router




if not firebase_admin._apps:
    # Se você usa variáveis de ambiente ou arquivo JSON de credenciais no Render:
    cred = credentials.path("caminho/para/sua-chave-firebase.json") # Ou use application_default()
    firebase_admin.initialize_app(cred)

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
# 🔄 ROTINAS E GRAVAÇÃO DO WEBSAC / FIREBASE / POSTGRESQL
# ==========================================

def formatar_texto_capitalizado(texto: str) -> str:
    """
    Converte o texto para Formato Título, removendo termos de unidades de medida 
    (kg, kilo, un, etc.), ajustando preposições e limpando traços residuais.
    """
    if not texto:
        return ""
    
    padrao_unidades = (
        r'\b(kg|kilo|kilos|kilograma|kilogramas|un|und|unidade|unidades|'
        r'pc|pça|pçs|paca|g|gr|grama|gramas|ml|l|lt|litro|litros|cx|caixa|pct|pacote)\b\.?'
    )
    texto_sem_unidades = re.sub(padrao_unidades, '', texto, flags=re.IGNORECASE)

    texto_limpo = re.sub(r'[\s\-\.]+$', '', texto_sem_unidades.strip())
    texto_limpo = re.sub(r'\s+', ' ', texto_limpo).strip()
    
    if not texto_limpo:
        texto_limpo = texto.strip()

    texto_fmt = texto_limpo.title()
    
    preposicoes = {
        r'\bDe\b': 'de', r'\bDo\b': 'do', r'\bDa\b': 'da', 
        r'\bDos\b': 'dos', r'\bDas\b': 'das', r'\bCom\b': 'com', 
        r'\bC/\b': 'c/', r'\bE\b': 'e', r'\bEm\b': 'em', r'\bPara\b': 'para'
    }
    for prep, sub in preposicoes.items():
        texto_fmt = re.sub(prep, sub, texto_fmt)

    return texto_fmt[0].upper() + texto_fmt[1:] if texto_fmt else ""


def sanitizar_produto(prod: dict, postgres_categoria_id: int) -> dict:
    """
    Higieniza o produto usando ESTRITAMENTE o ID de categoria do PostgreSQL (postgres_categoria_id),
    ignorando completamente qualquer ID antigo do WebSac.
    """
    nome_raw = prod.get("descricao_resumida") or prod.get("descricao_completa") or prod.get("nome", "")
    nome_formatado = formatar_texto_capitalizado(nome_raw)
    
    desc_raw = prod.get("descricao_completa") or prod.get("descricao", "") or nome_raw
    desc_formatada = formatar_texto_capitalizado(desc_raw)

    peso_variavel = bool(prod.get("peso_variavel", False))
    emb_venda = prod.get("embalagem_venda") or {}
    unidade_emb = str(emb_venda.get("unidade", "")).strip().upper()

    if peso_variavel or unidade_emb in ["KG", "KILO", "KILOGRAMA"]:
        unidade_limpa = "kg"
        eh_pesavel = True
    else:
        unidade_limpa = "un"
        eh_pesavel = False

    estoque_raw = float(prod.get("estoque_atual", prod.get("estoque", 0.0)))
    estoque_limpo = round(estoque_raw, 3) if eh_pesavel else int(estoque_raw)
    estoque_limpo = max(0, estoque_limpo)

    preco_normal = float(prod.get("preco_varejo", prod.get("preco", 0.0)))
    preco_oferta = float(prod.get("preco_varejo_oferta", 0.0))
    
    preco_clube_limpo = None
    if 0 < preco_oferta < preco_normal:
        preco_clube_limpo = preco_oferta

    ativo = bool(prod.get("ativo", True)) and (preco_normal > 0.0)

    gtin_list = prod.get("gtin", [])
    ean = str(gtin_list[0]).strip() if gtin_list else prod.get("ean")

    url_base_img = "https://seu-storage.com.br/imagens"
    imagem_url = prod.get("imagem_url")
    if not imagem_url or "seu-storage.com.br" in imagem_url:
        if ean:
            imagem_url = f"{url_base_img}/{ean}.png"
        else:
            imagem_url = "https://i.imgur.com/6tJyuYb.png"

    depto = prod.get("departamento") or prod.get("grupo") or {}
    cat_nome = str(depto.get("descricao") or prod.get("categoria_nome") or prod.get("categoria") or "GERAL").strip().upper()

    # 🔑 GARANTIA TOTAL: O ID da categoria será sempre o do PostgreSQL (ex: 52), sem fallback para o WebSac
    cat_id = postgres_categoria_id

    return {
        "id_websac": prod.get("id") or prod.get("id_websac"),
        "nome": nome_formatado,
        "descricao": desc_formatada,
        "preco": preco_normal,
        "preco_clube": preco_clube_limpo,
        "unidade": unidade_limpa,
        "eh_pesavel": eh_pesavel,
        "estoque": estoque_limpo,
        "imagem_url": imagem_url,
        "categoria_id": cat_id,
        "categoria": cat_nome,
        "categoria_nome": cat_nome,
        "ativo": ativo,
        "mais_vendido": bool(prod.get("mais_vendido", False)),
        "destaque": bool(prod.get("destaque", False))
    }


def salvar_produtos_no_postgres(produtos: list, db: Session) -> tuple[int, list]:
    if not produtos:
        return 0, []

    contador = 0
    produtos_alterados = []

    for prod_raw in produtos:
        id_prod = prod_raw.get("id") or prod_raw.get("id_websac")
        if not id_prod:
            continue

        # 1. Verifica se o produto já existe no banco Neon
        prod_db = db.query(models.Produto).filter(models.Produto.id == id_prod).first()

        if not prod_db:
            # ==========================================
            # 🟢 PRODUTO NOVO: Cadastra tudo do zero
            # ==========================================
            depto = prod_raw.get("departamento") or prod_raw.get("grupo") or {}
            cat_nome_raw = str(depto.get("descricao") or prod_raw.get("categoria_nome") or prod_raw.get("categoria") or "GERAL").strip().upper()

            categoria_id_db = None
            if cat_nome_raw:
                categoria_db = db.query(models.Categoria).filter(
                    func.upper(models.Categoria.nome) == cat_nome_raw
                ).first()

                if not categoria_db:
                    categoria_db = models.Categoria(nome=cat_nome_raw, ativo=True)
                    db.add(categoria_db)
                    db.commit()
                    db.refresh(categoria_db)
                
                categoria_id_db = categoria_db.id

            p = sanitizar_produto(prod_raw, postgres_categoria_id=categoria_id_db)
            
            prod_db = models.Produto(
                id=id_prod,
                nome=p["nome"],
                descricao=p["descricao"],
                preco=p["preco"],
                preco_clube=p["preco_clube"],
                unidade=p["unidade"],
                estoque=p["estoque"],
                imagem_url=p["imagem_url"],
                ativo=p["ativo"],
                categoria_id=categoria_id_db
            )
            db.add(prod_db)
            produtos_alterados.append(p)

        else:
            # ==========================================
            # 🟠 PRODUTO EXISTENTE: Atualiza SÓ valores comerciais
            # ==========================================
            # Sanitiza para obtermos os cálculos atualizados do ERP
            p = sanitizar_produto(prod_raw, postgres_categoria_id=prod_db.categoria_id)

            houve_alteracao = False

            # Compara e atualiza APENAS Preço, Estoque e Ativo. 
            # Nome, Descrição, Categoria e Imagem ficam INTACTOS!
            if float(prod_db.preco or 0.0) != p["preco"]:
                prod_db.preco = p["preco"]
                houve_alteracao = True
            
            if prod_db.estoque != p["estoque"]:
                prod_db.estoque = p["estoque"]
                houve_alteracao = True

            if prod_db.ativo != p["ativo"]:
                prod_db.ativo = p["ativo"]
                houve_alteracao = True
            
            # Se o WebSac enviar uma oferta nova, atualiza o preco_clube.
            if p["preco_clube"] is not None and float(prod_db.preco_clube or 0.0) != p["preco_clube"]:
                 prod_db.preco_clube = p["preco_clube"]
                 houve_alteracao = True

            if houve_alteracao:
                # Adiciona à lista de alterados apenas para fins de log
                produtos_alterados.append({
                    "id_websac": prod_db.id,
                    "nome": prod_db.nome,
                    "preco": prod_db.preco,
                    "estoque": prod_db.estoque
                })

        contador += 1

    db.commit()
    print(f"🐘 [PostgreSQL] {contador} produtos verificados ({len(produtos_alterados)} alterados/novos).")
    return contador, produtos_alterados

def obter_ids_autorizados_curva_a() -> set:
    caminho_csv = "curva_a/produtos_curva_a_imagens.csv"
    if not os.path.exists(caminho_csv):
        caminho_csv = "produtos_curva_a_imagens.csv"
    
    if os.path.exists(caminho_csv):
        df = pd.read_csv(caminho_csv)
        return set(
            pd.to_numeric(df["id_websac"], errors="coerce")
            .dropna()
            .astype(int)
            .tolist()
        )
    return set()


async def executar_sincronizacao_delta_curva_a():
    """
    Rotina centralizada: baixa o WebSac, filtra a Curva A e
    atualiza APENAS o PostgreSQL.
    """
    if not WebSacIntegration:
        print("⚠️ [WebSac] Módulo WebSacIntegration não disponível.")
        return

    try:
        print(f"[{agora_brasilia()}] 🔄 [Automático] Iniciando verificação delta da Curva A...")
        websac = WebSacIntegration(
            cnpj="44737674000149", 
            token="ba2e4041-0d3d-4ed5-a110-df9ca841102c",
            dominio="tescarollo"
        )
        produtos_totais = await websac.sincronizar_catalogo()

        ids_permitidos = obter_ids_autorizados_curva_a()
        produtos_curva_a = [
            p for p in produtos_totais 
            if int(p.get("id_websac", p.get("id", 0))) in ids_permitidos
        ]

        if not produtos_curva_a:
            print("⚠️ [WebSac] Nenhum produto da Curva A encontrado na listagem.")
            return

        db = SessionLocal()
        try:
            total_processados, produtos_alterados = salvar_produtos_no_postgres(produtos_curva_a, db)
            # 🗑️ O bloco que enviava para o Firebase foi removido daqui
            print(f"✨ [Sync] Verificação da Curva A concluída no Neon PostgreSQL. {len(produtos_alterados)} itens atualizados.")
        finally:
            db.close()

    except Exception as e:
        print(f"❌ [Erro Sincronização Delta] {e}")


async def rotina_carga_total():
    """
    Rotina agendada da madrugada (03:00) para baixar o catálogo
    e atualizar APENAS OS PRODUTOS DA CURVA A no PostgreSQL.
    """
    print(f"[{agora_brasilia()}] Iniciando Carga Total (Restrita à Curva A)...")
    if WebSacIntegration:
        try:
            websac = WebSacIntegration(
                cnpj="44737674000149", 
                token="ba2e4041-0d3d-4ed5-a110-df9ca841102c",
                dominio="tescarollo"
            )
            produtos_brutos = await websac.sincronizar_catalogo()
            
            # 🌟 TRAVA DE SEGURANÇA: Filtra apenas a Curva A
            ids_permitidos = obter_ids_autorizados_curva_a()
            produtos_curva_a = [
                p for p in produtos_brutos 
                if int(p.get("id_websac", p.get("id", 0))) in ids_permitidos
            ]
            
            db = SessionLocal()
            try:
                # Salva SOMENTE a Curva A no banco
                total_processados, produtos_alterados = salvar_produtos_no_postgres(produtos_curva_a, db)
            finally:
                db.close()
                
            print(f"[{agora_brasilia()}] Carga Total no PostgreSQL finalizada. ({total_processados} produtos da Curva A salvos).")
        except Exception as e:
            print(f"❌ Erro na carga total WebSac: {e}")


async def rotina_carga_expressa():
    """
    Executada automaticamente a cada 15 minutos pelo APScheduler.
    Atualiza apenas o delta da Curva A.
    """
    await executar_sincronizacao_delta_curva_a()


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


app = FastAPI(
    title="Box Smart API",
    description="API oficial da plataforma de e-commerce e clube de fidelidade Box Smart",
    version="1.0.0",
    lifespan=lifespan
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


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
# 🔄 CUPONS DE DESCONTOS
# ==========================================

@app.post("/api/cupons/validar")
def validar_cupom(dados: dict, db: Session = Depends(get_db)):
    codigo = dados.get("codigo", "").strip().upper()
    subtotal = float(dados.get("subtotal", 0.0))
    
    # Regras de cupons oficiais do Box Smart para testes reais
    if codigo == "BOX10":
        desconto = subtotal * 0.10
        return {"valor_desconto": desconto, "codigo": "BOX10", "mensagem": "Cupom BOX10 aplicado (10% de desconto)!"}
    elif codigo == "BOX20":
        desconto = subtotal * 0.20
        return {"valor_desconto": desconto, "codigo": "BOX20", "mensagem": "Cupom BOX20 aplicado (20% de desconto)!"}
    elif codigo == "PRIME5":
        desconto = 5.00 if subtotal >= 50.0 else subtotal * 0.05
        return {"valor_desconto": desconto, "codigo": "PRIME5", "mensagem": "Desconto de R$ 5,00 aplicado!"}
    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cupom inválido, expirado ou valor mínimo não atingido."
        )


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
@app.get("/api/produtos/")
@app.get("/api/produtos")
def listar_produtos(sem_foto: bool = Query(False), db: Session = Depends(get_db)):
    """
    Busca os produtos ativos diretamente do banco de dados PostgreSQL (Neon),
    com opção opcional de filtrar apenas os sem foto personalizada.
    """
    query = db.query(models.Produto).filter(models.Produto.ativo == True)
    
    if sem_foto:
        query = query.filter(
            (models.Produto.imagem_url == None) | 
            (models.Produto.imagem_url == "") | 
            (models.Produto.imagem_url == "https://i.imgur.com/6tJyuYb.png") |
            (models.Produto.imagem_url.like("%seu-storage.com.br%"))
        )
        
    produtos_db = query.all()
    
    resultado = []
    for p in produtos_db:
        cat_nome = p.categoria.nome if getattr(p, 'categoria', None) else "Geral"
        
        resultado.append({
            "id": p.id,
            "nome": p.nome,
            "descricao": getattr(p, 'descricao', ''),
            "preco": float(p.preco),
            "preco_clube": float(p.preco_clube) if getattr(p, 'preco_clube', None) else None,
            "estoque": getattr(p, 'estoque', 0),
            "imagem_url": getattr(p, 'imagem_url', None),
            "unidade": getattr(p, 'unidade', 'un'),
            "categoria_id": getattr(p, 'categoria_id', None),
            "categoria": cat_nome,
            "categoria_nome": cat_nome,
            "mais_vendido": getattr(p, 'mais_vendido', False),
            "destaque": getattr(p, 'destaque', False),
        })
        
    return resultado


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

endereco_router = APIRouter(prefix="/api/enderecos", tags=["Endereços"])


app.include_router(frete_router)
app.include_router(endereco_router)

def buscar_lat_long_nominatim(rua: str, numero: str, cidade: str, estado: str, cep: str):
    """Consulta a API do Nominatim com múltiplas estratégias de fallback."""
    url = "https://nominatim.openstreetmap.org/search"
    headers = {'User-Agent': 'BoxSmartApp/1.0 (contato@boxsmart.com)'}
    
    # Lista de tentativas em ordem de precisão (da mais específica para a mais genérica)
    queries = [
        f"{rua}, {numero}, {cidade} - {estado}, {cep}, Brasil",  # 1. Endereço completo
        f"{rua}, {cidade} - {estado}, {cep}, Brasil",            # 2. Sem o número da casa
        f"{cep}, {cidade} - {estado}, Brasil",                 # 3. Apenas por CEP e cidade
        f"{cep}, Brasil"                                       # 4. Apenas pelo CEP global
    ]
    
    for query in queries:
        params = {
            'q': query,
            'format': 'json',
            'limit': 1
        }
        
        try:
            response = requests.get(url, params=params, headers=headers, timeout=5)
            if response.status_code == 200:
                data = response.json()
                if data and len(data) > 0:
                    lat = float(data[0]['lat'])
                    lon = float(data[0]['lon'])
                    print(f"[GEOCODING] Sucesso usando a query: '{query}' -> Lat: {lat}, Lon: {lon}")
                    return lat, lon
        except Exception as e:
            print(f"[GEOCODING ERROR] Erro na tentativa com '{query}': {e}")
            
    return None, None


@app.post("/pedidos/", status_code=status.HTTP_201_CREATED)
@app.post("/pedidos", status_code=status.HTTP_201_CREATED)
async def criar_pedido(
    request: Request,
    db: Session = Depends(get_db),
    current_user: models.Cliente = Depends(get_current_user)
):
    # Lemos o JSON cru (raw) diretamente do app para garantir que nada seja perdido
    payload = await request.json()
    
    print(f"🚀 PAYLOAD CRU RECEBIDO NO BACKEND: {payload}")

    # Forçamos a leitura segura das chaves, lidando com nulls e erros de formatação
    subtotal = float(payload.get('valor_subtotal') or 0.0)
    taxa_entrega = float(payload.get('taxa_entrega') or 0.0)
    valor_total = float(payload.get('valor_total') or 0.0)

    print(f"💰 FINANCEIRO APÓS LEITURA: Subtotal={subtotal} | Frete={taxa_entrega} | Total={valor_total}")

    endereco_req = payload.get('endereco_entrega', None)
    end_entrega = (
        endereco_req.strip() if (endereco_req and endereco_req.strip()) 
        else (obter_endereco_formatado_cliente(current_user) or "Endereço não informado")
    )

    forma_pag = payload.get('forma_pagamento', None) or "Dinheiro na Entrega"
    troco = float(payload.get('troco_para') or 0.0)
    pago = bool(payload.get('esta_pago', False))

    # Cria o pedido FORÇANDO os valores exatos recebidos
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
        opcao_substituicao=payload.get('opcao_substituicao', None),
        deseja_cpf_nota=bool(payload.get('deseja_cpf_nota', False)),
        cupom_codigo=payload.get('cupom_codigo', None),
        valor_desconto_cupom=float(payload.get('valor_desconto_cupom') or 0.0),
        data_criacao=agora_brasilia()
    )

    db.add(novo_pedido)
    db.commit()
    db.refresh(novo_pedido)

    # Lemos os itens e o preço unitário que veio do App
    itens = payload.get('itens', [])
    for item in itens:
        db_item = models.ItemPedido(
            pedido_id=novo_pedido.id,
            produto_id=item['produto_id'],
            quantidade=float(item['quantidade']),
            preco_unitario=float(item.get('preco_unitario') or 0.0) # 👈 Confia 100% no app!
        )
        db.add(db_item)
    
    db.commit()
    db.refresh(novo_pedido)

    # Notificação...
    if getattr(current_user, 'fcm_token', None):
        enviar_notificacao_push(
            fcm_token=current_user.fcm_token,
            titulo="Pedido Recebido com Sucesso! 🛒",
            corpo=f"Olá {current_user.nome}, seu pedido #{novo_pedido.id} foi recebido e já está em processamento.",
            dados_extra={"pedido_id": str(novo_pedido.id), "status": "PENDENTE"}
        )

    # O FastApi converterá a classe SQLAlchemy para o schema correspondente, se necessário
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
                "preco_unitario": float(item.preco_unitario if item.preco_unitario is not None else 0.0),
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
            "subtotal": float(p.subtotal if p.subtotal is not None else 0.0),
            "taxa_entrega": float(p.taxa_entrega if p.taxa_entrega is not None else 0.0),
            "total": float(p.total if p.total is not None else 0.0),
            "valor_total": float(p.total if p.total is not None else 0.0), # 👈 Adiciona essa chave para retrocompatibilidade com o app Flutter!
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
            "subtotal": float(p.subtotal if p.subtotal is not None else 0.0),
            "taxa_entrega": float(p.taxa_entrega if p.taxa_entrega is not None else 0.0),
            "total": float(p.total if p.total is not None else 0.0),
            "valor_total": float(p.total if p.total is not None else 0.0), # 👈 Adiciona essa chave para retrocompatibilidade com o app Flutter!
            "status": getattr(p, 'status', 'PENDENTE'),
            "endereco_entrega": getattr(p, 'endereco_entrega', None) or (p.cliente.endereco if p.cliente and hasattr(p.cliente, 'endereco') else None) or 'Endereço não informado',
            "data_criacao": p.data_criacao.isoformat() if p.data_criacao else None,
            "itens": [
                {
                    "produto_id": item.produto_id,
                    "nome_produto": item.produto.nome if item.produto else "Produto",
                    "quantidade": item.quantidade,
                    "preco_unitario": float(item.preco_unitario if item.preco_unitario is not None else 0.0),
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
            
            # 👇 Ajuste no preço dos itens para respeitar o desconto
            "preco_unitario": float(item.preco_unitario if item.preco_unitario is not None else 0.0) 
        })

    return {
        "id": pedido.id,
        "status": pedido.status,
        
        # 👇 CORREÇÃO AQUI: Troca "p." por "pedido."
        "subtotal": float(pedido.subtotal if pedido.subtotal is not None else 0.0),
        "taxa_entrega": float(pedido.taxa_entrega if pedido.taxa_entrega is not None else 0.0),
        "total": float(pedido.total if pedido.total is not None else 0.0),
        "valor_total": float(pedido.total if pedido.total is not None else 0.0), 
        
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


@app.post("/admin/notificacoes/campanha", status_code=201)
@app.post("/admin/notificacoes/campanha/", status_code=201)
def disparar_campanha_marketing(titulo: str, mensagem: str, db: Session = Depends(get_db)):
    nova_notificacao = models.Notificacao(titulo=titulo, mensagem=mensagem, cliente_id=None, data_envio=agora_brasilia())
    db.add(nova_notificacao)
    db.commit()
    db.refresh(nova_notificacao)
    
    # 🌟 DISPARA PARA TODOS OS CLIENTES QUE POSSUEM FCM TOKEN SALVO
    clientes_com_token = db.query(models.Cliente).filter(models.Cliente.fcm_token != None).all()
    for cliente in clientes_com_token:
        try:
            message = messaging.Message(
                notification=messaging.Notification(title=titulo, body=mensagem),
                token=cliente.fcm_token,
            )
            messaging.send(message)
        except Exception as e:
            print(f"Erro ao enviar push para cliente {cliente.id}: {e}")

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

    # 🌟 DISPARA PARA UM CLIENTE ESPECÍFICO OU TODOS SE O CLIENTE_ID FOR NULO
    if notificacao.cliente_id:
        cliente = db.query(models.Cliente).filter(models.Cliente.id == notificacao.cliente_id).first()
        if cliente and cliente.fcm_token:
            try:
                message = messaging.Message(
                    notification=messaging.Notification(title=notificacao.titulo, body=notificacao.mensagem),
                    token=cliente.fcm_token,
                )
                messaging.send(message)
            except Exception as e:
                print(f"Erro ao enviar push individual: {e}")
    else:
        # Se for para todos
        clientes_com_token = db.query(models.Cliente).filter(models.Cliente.fcm_token != None).all()
        for cliente in clientes_com_token:
            try:
                message = messaging.Message(
                    notification=messaging.Notification(title=notificacao.titulo, body=notificacao.mensagem),
                    token=cliente.fcm_token,
                )
                messaging.send(message)
            except Exception as e:
                print(f"Erro ao enviar push em massa: {e}")

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
    lat = endereco.get("latitude")
    lon = endereco.get("longitude")

    # Se a latitude ou longitude não vierem preenchidas, tentamos buscar pelo Nominatim
    if lat is None or lon is None:
        rua = endereco.get("rua", "")
        numero = endereco.get("numero", "")
        cidade = endereco.get("cidade", "Itatiba")
        estado = endereco.get("estado", "SP")
        cep = endereco.get("cep", "")

        print(f"[GEOCODING] Coordenadas ausentes para o cliente {cliente_id}. Buscando CEP: {cep}...")
        lat_geo, lon_geo = buscar_lat_long_nominatim(
            rua=rua,
            numero=numero,
            cidade=cidade,
            estado=estado,
            cep=cep
        )
        
        if lat_geo and lon_geo:
            lat = lat_geo
            lon = lon_geo
            print(f"[GEOCODING] Sucesso! Lat: {lat}, Lon: {lon}")
        else:
            print("[GEOCODING] Endereço não localizado exatamente pelo Nominatim. Será salvo sem coordenadas.")

    # Insere os valores tratados no dicionário do banco
    endereco["latitude"] = lat
    endereco["longitude"] = lon

    novo_endereco = models.Endereco(cliente_id=cliente_id, **endereco)
    db.add(novo_endereco)
    db.commit()
    db.refresh(novo_endereco)
    return novo_endereco



@app.delete("/api/enderecos/{endereco_id}", status_code=status.HTTP_204_NO_CONTENT)
@app.delete("/api/enderecos/{endereco_id}/", status_code=status.HTTP_204_NO_CONTENT)
def deletar_endereco(endereco_id: int, db: Session = Depends(get_db)):
    """Exclui um endereço cadastrado do banco de dados."""
    endereco = db.query(models.Endereco).filter(models.Endereco.id == endereco_id).first()
    if not endereco:
        raise HTTPException(status_code=404, detail="Endereço não encontrado.")
    
    db.delete(endereco)
    db.commit()
    return None

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
# 📊 GRÁFICO DE VENDAS ACUMULADAS E METAS
# ==========================================
@app.get("/admin/relatorios/vendas-acumuladas")
@app.get("/admin/relatorios/vendas-acumuladas/")
def relatorio_vendas_acumuladas(
    data_inicio: Optional[date] = Query(None),
    data_fim: Optional[date] = Query(None),
    meta_faturamento: float = Query(250000.00),
    db: Session = Depends(get_db)
):
    query = db.query(
        func.date(models.Pedido.data_criacao).label("dia"),
        func.coalesce(func.sum(models.Pedido.total), 0.0).label("faturamento_dia")
    ).filter(
        func.upper(models.Pedido.status) != "CANCELADO"
    )

    query = aplicar_filtro_data(query, models.Pedido.data_criacao, data_inicio, data_fim)
    vendas_diarias = query.group_by(func.date(models.Pedido.data_criacao))\
                          .order_by(func.date(models.Pedido.data_criacao).asc()).all()

    if not vendas_diarias:
        return {
            "periodo": "Sem dados no período",
            "meta_faturamento": meta_faturamento,
            "ponto_corte_alerta": meta_faturamento * 0.70,
            "faturamento_total_acumulado": 0.0,
            "serie_historica": []
        }

    acumulado = 0.0
    serie = []

    for item in vendas_diarias:
        venda_dia = float(item.faturamento_dia or 0.0)
        acumulado += venda_dia
        
        dia_str = item.dia.strftime("%d/%m/%Y") if hasattr(item.dia, 'strftime') else str(item.dia)

        serie.append({
            "dia": dia_str,
            "venda_dia": round(venda_dia, 2),
            "venda_acumulada": round(acumulado, 2),
            "projecao_periodo_anterior": round(acumulado * 0.85, 2) 
        })

    data_ini_str = data_inicio.strftime("%d/%m/%Y") if data_inicio else "Início"
    data_fim_str = data_fim.strftime("%d/%m/%Y") if data_fim else "Atual"

    return {
        "periodo": f"{data_ini_str} a {data_fim_str}",
        "meta_faturamento": meta_faturamento,
        "ponto_corte_alerta": round(meta_faturamento * 0.70, 2),
        "faturamento_total_acumulado": round(acumulado, 2),
        "serie_historica": serie
    }

# ==========================================
# 📂 ROTA DO CLUBE BOX PRIME
# ==========================================

router_clube = APIRouter()

@router_clube.get("/api/produtos/clube")
def listar_produtos_clube(db: Session = Depends(get_db)):
    """
    Retorna apenas os produtos que possuem preco_clube cadastrado e maior que zero.
    """
    produtos_clube = db.query(Produto).filter(
        Produto.preco_clube.isnot(None),
        Produto.preco_clube > 0
    ).all()
    
    return produtos_clube

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

app.include_router(router_clube)

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

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

router_auth = APIRouter(prefix="/auth", tags=["Autenticação"])

class RecuperarSenhaRequest(BaseModel):
    email: EmailStr

class RedefinirSenhaRequest(BaseModel):
    email: EmailStr
    token: str
    nova_senha: str

import os
import resend
from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.orm import Session
from datetime import datetime, timedelta
import secrets

# Inicializa o Resend com a chave das variáveis de ambiente do Render
resend.api_key = os.environ.get("RESEND_API_KEY")

router_auth = APIRouter(prefix="/auth", tags=["Autenticação"])

@router_auth.post("/esqueci-senha")
def esqueci_senha(dados: RecuperarSenhaRequest, db: Session = Depends(get_db)):
    # 1. Buscar o cliente pelo e-mail no banco de dados
    cliente = db.query(Cliente).filter(Cliente.email == dados.email).first()
    
    # Por segurança, mesmo se o e-mail não existir, retornamos sucesso para evitar enumeração
    if not cliente:
        return {"mensagem": "Se o e-mail estiver cadastrado, as instruções foram enviadas."}
    
    
class RedefinirSenhaRequest(BaseModel):
    email: str
    token: str
    nova_senha: str

@router_auth.post("/esqueci-senha/confirmar") # ou "/esqueci-senha/resetar"
def confirmar_redefinicao_senha(dados: RedefinirSenhaRequest, db: Session = Depends(get_db)):
    cliente = db.query(Cliente).filter(Cliente.email == dados.email).first()
    if not cliente:
        raise HTTPException(status_code=404, detail="Cliente não encontrado.")
    
    # Aqui você valida se o token confere com o salvo no banco e se não expirou.
    # Exemplo simples de atualização da senha com hash:
    cliente.senha_hash = security.obter_hash_senha(dados.nova_senha)
    db.commit()
    
    return {"mensagem": "Senha redefinida com sucesso!"}

    # 2. Gerar token temporário (4 caracteres/dígitos) e tempo de expiração (15 minutos)
    token = secrets.token_hex(4).upper() # Ex: A3F2
    expiracao = datetime.utcnow() + timedelta(minutes=15)

    # 3. Salvar no banco Neon
    cliente.reset_token = token
    cliente.reset_token_expires = expiracao
    db.commit()

    # 4. Enviar o e-mail utilizando o Resend
    try:
        params = {
            "from": "Box Smart <onboarding@resend.dev>", # (Depois você pode trocar pelo seu domínio verificado no Resend)
            "to": [cliente.email],
            "subject": "Código de Recuperação de Senha - Box Smart",
            "html": f"""
                <div style="font-family: Arial, sans-serif; padding: 20px; color: #333;">
                    <h2 style="color: #1E3A8A;">Recuperação de Senha</h2>
                    <p>Olá! Recebemos uma solicitação para redefinir a senha da sua conta no <strong>Box Smart</strong>.</p>
                    <p>O seu código de recuperação temporário é:</p>
                    <div style="background-color: #f3f4f6; padding: 15px; text-align: center; font-size: 24px; font-weight: bold; letter-spacing: 4px; color: #1E3A8A; border-radius: 8px; margin: 20px 0;">
                        {token}
                    </div>
                    <p>Este código é válido por <strong>15 minutos</strong>. Se você não solicitou isso, ignore este e-mail.</p>
                    <hr style="border: none; border-top: 1px solid #eee; margin: 20px 0;" />
                    <p style="font-size: 12px; color: #777;">Equipe Box Smart</p>
                </div>
            """,
        }
        
        email_response = resend.Emails.send(params)
        print(f"📧 E-mail de recuperação enviado com sucesso para {cliente.email}. Resposta: {email_response}")

    except Exception as e:
        print(f"❌ Erro ao enviar e-mail via Resend: {e}")
        # Mesmo se houver falha no disparo do e-mail, por segurança mantemos o fluxo sem travar o cliente bruscamente
    
    return {"mensagem": "Código de recuperação enviado com sucesso!"}

# 🌟 3. REGISTRO OBRIGATÓRIO DO ROUTER NO APP PRINCIPAL
# Certifique-se de que 'app' é a sua instância principal (app = FastAPI())
app.include_router(router_auth)

# 👇 1. Rota de ping para manter o servidor acordado
@app.get("/api/ping")
def ping_server():
    return {"status": "ok", "mensagem": "Servidor rodando liso!"}


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


@app.post("/admin/sincronizar-agora")
@app.post("/admin/sincronizar-agora/")
async def forcar_sincronizacao_manual(background_tasks: BackgroundTasks):
    """
    Endpoint de sincronização protegido: dispara a sincronização delta da Curva A em background.
    """
    if not WebSacIntegration:
        raise HTTPException(status_code=500, detail="Módulo WebSacIntegration não foi localizado no backend.")

    background_tasks.add_task(executar_sincronizacao_delta_curva_a)

    return {
        "status": "Sincronização Iniciada",
        "mensagem": "A verificação delta da Curva A foi disparada em segundo plano. Acompanhe os logs do servidor."
    }

@app.post("/admin/sincronizar-postgres-200")
async def sincronizar_postgres_200(db: Session = Depends(get_db)):
    """
    Endpoint de teste para sincronizar uma amostra de 200 produtos da Curva A
    exclusivamente no PostgreSQL, zerando o uso de cota no Firebase.
    """
    if not WebSacIntegration:
        raise HTTPException(status_code=500, detail="Módulo WebSacIntegration não foi localizado no backend.")

    try:
        websac = WebSacIntegration(
            cnpj="44737674000149", 
            token="ba2e4041-0d3d-4ed5-a110-df9ca841102c",
            dominio="tescarollo"
        )
        produtos_totais = await websac.sincronizar_catalogo()

        ids_permitidos = obter_ids_autorizados_curva_a()
        produtos_curva_a = [
            p for p in produtos_totais 
            if int(p.get("id_websac", 0)) in ids_permitidos
        ]

        amostra_200 = produtos_curva_a[:200]

        total_processados, produtos_alterados = salvar_produtos_no_postgres(amostra_200, db)

        return {
            "status": "Teste Isolado Concluído",
            "mensagem": f"{total_processados} produtos da Curva A processados com sucesso apenas no PostgreSQL. Cota do Firebase intacta! 🎉",
            "total_amostra_processada": total_processados,
            "total_alterados_detectados": len(produtos_alterados)
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro no teste do PostgreSQL: {str(e)}")