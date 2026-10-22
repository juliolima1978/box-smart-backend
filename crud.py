from sqlalchemy.orm import Session, joinedload
from sqlalchemy import func
from fastapi import HTTPException
import models
import schemas
from typing import List, Optional


# --- Categorias ---
def get_categorias(db: Session, skip: int = 0, limit: int = 100):
    return db.query(models.Categoria).offset(skip).limit(limit).all()

def create_categoria(db: Session, categoria: schemas.CategoriaCreate):
    dados = categoria.model_dump() if hasattr(categoria, 'model_dump') else categoria.dict()
    db_categoria = models.Categoria(**dados)
    db.add(db_categoria)
    db.commit()
    db.refresh(db_categoria)
    return db_categoria


# --- Produtos ---
def get_produtos(db: Session, skip: int = 0, limit: int = 100):
    return db.query(models.Produto).offset(skip).limit(limit).all()

def create_produto(db: Session, produto: schemas.ProdutoCreate):
    dados = produto.model_dump() if hasattr(produto, 'model_dump') else produto.dict()
    db_produto = models.Produto(**dados)
    db.add(db_produto)
    db.commit()
    db.refresh(db_produto)
    return db_produto

def update_produto(db: Session, produto_id: int, produto: schemas.ProdutoCreate):
    db_produto = db.query(models.Produto).filter(models.Produto.id == produto_id).first()
    if not db_produto:
        return None
    
    dados = produto.model_dump() if hasattr(produto, 'model_dump') else produto.dict()
    if dados.get('categoria_id') == 0:
        dados['categoria_id'] = None

    for chave, valor in dados.items():
        setattr(db_produto, chave, valor)

    db.commit()
    db.refresh(db_produto)
    return db_produto


# --- Clientes e Fidelidade ---
def get_cliente_by_email(db: Session, email: str):
    return db.query(models.Cliente).filter(models.Cliente.email == email).first()

def get_clientes(db: Session, skip: int = 0, limit: int = 100):
    return db.query(models.Cliente).offset(skip).limit(limit).all()

def create_cliente(db: Session, cliente: schemas.ClienteCreate):
    dados = cliente.model_dump() if hasattr(cliente, 'model_dump') else cliente.dict()
    
    # Monta o endereço de forma segura em Python puro
    rua = dados.get('rua')
    numero = dados.get('numero', '')
    bairro = dados.get('bairro', '')
    endereco_completo = f"{rua}, {numero} - {bairro}" if rua else None

    db_cliente = models.Cliente(
        nome=dados.get('nome'),
        email=dados.get('email'),
        senha_hash=dados.get('senha'),  # Lembre-se de aplicar hash se utilizar passlib
        telefone=dados.get('telefone'),
        cpf=dados.get('cpf'),
        endereco=endereco_completo,
        is_admin=False
    )
    db.add(db_cliente)
    db.flush()
    
    db_fidelidade = models.Fidelidade(
        cliente_id=db_cliente.id,
        pontos=10,
        nivel="Bronze"
    )
    db.add(db_fidelidade)
    db.commit()
    db.refresh(db_cliente)
    return db_cliente

# --- Pedidos ---
def criar_pedido(db: Session, pedido: schemas.PedidoCreate):
    cliente = db.query(models.Cliente).filter(models.Cliente.id == pedido.cliente_id).first()
    if not cliente:
        raise HTTPException(status_code=404, detail="Cliente não encontrado.")
    
    total_pedido = 0.0
    itens_para_salvar = []

    for item in pedido.itens:
        produto = db.query(models.Produto).filter(models.Produto.id == item.produto_id).first()
        if not produto:
            raise HTTPException(status_code=404, detail=f"Produto ID {item.produto_id} não encontrado.")
        
        if produto.estoque < item.quantidade:
            raise HTTPException(
                status_code=400, 
                detail=f"Estoque insuficiente para '{produto.nome}'. Disponível: {produto.estoque}"
            )
        
        produto.estoque -= item.quantidade
        subtotal = produto.preco * item.quantidade
        total_pedido += subtotal
        
        itens_para_salvar.append(
            models.ItemPedido(
                produto_id=produto.id,
                quantidade=item.quantidade,
                preco_unitario=produto.preco
            )
        )

    db_pedido = models.Pedido(
        cliente_id=pedido.cliente_id,
        total=total_pedido,
        status="Pendente"
    )
    db.add(db_pedido)
    db.flush()

    for item_db in itens_para_salvar:
        item_db.pedido_id = db_pedido.id
        db.add(item_db)
    
    fidelidade = db.query(models.Fidelidade).filter(models.Fidelidade.cliente_id == cliente.id).first()
    if fidelidade:
        fidelidade.pontos += int(total_pedido)
        if fidelidade.pontos >= 500:
            fidelidade.nivel = "Diamante"
        elif fidelidade.pontos >= 200:
            fidelidade.nivel = "Ouro"
        elif fidelidade.pontos >= 100:
            fidelidade.nivel = "Prata"

    db.commit()
    db.refresh(db_pedido)
    return db_pedido

def get_pedidos_cliente(db: Session, cliente_id: int):
    return (
        db.query(models.Pedido)
        .options(
            joinedload(models.Pedido.itens)
            .joinedload(models.ItemPedido.produto)
            .joinedload(models.Produto.categoria)
        )
        .filter(models.Pedido.cliente_id == cliente_id)
        .order_by(models.Pedido.id.desc())
        .all()
    )

def get_todos_pedidos(db: Session, skip: int = 0, limit: int = 100):
    return (
        db.query(models.Pedido)
        .options(
            joinedload(models.Pedido.cliente),
            joinedload(models.Pedido.itens)
            .joinedload(models.ItemPedido.produto)
            .joinedload(models.Produto.categoria)
        )
        .order_by(models.Pedido.id.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )


# --- Gestão de Banners ---
def criar_banner(db: Session, banner: schemas.BannerCreate):
    db_banner = models.Banner(
        titulo=banner.titulo,
        imagem_url=banner.imagem_url,
        ativo=banner.ativo,
        tipo=getattr(banner, 'tipo', 'principal'),
        ordem=getattr(banner, 'ordem', 0),  # 👈 1. Gravando a ordem recebida
        acao_tipo=getattr(banner, 'acao_tipo', None),  # 👈 2. Gravando tipo de ação
        acao_valor=getattr(banner, 'acao_valor', None)  # 👈 3. Gravando valor da ação
    )
    db.add(db_banner)
    db.commit()
    db.refresh(db_banner)
    return db_banner

def get_banners_ativos(db: Session):
    # 🌟 Adicionada ordenação crescente (.order_by) pelo campo ordem
    return (
        db.query(models.Banner)
        .filter(models.Banner.ativo == True)
        .order_by(models.Banner.ordem.asc())
        .all()
    )

def deletar_banner(db: Session, banner_id: int):
    banner = db.query(models.Banner).filter(models.Banner.id == banner_id).first()
    if banner:
        db.delete(banner)
        db.commit()
        return True
    return False


# --- Atualização de Preço do Clube ---
def atualizar_preco_clube(db: Session, produto_id: int, novo_preco_clube: float):
    produto = db.query(models.Produto).filter(models.Produto.id == produto_id).first()
    if not produto:
        raise HTTPException(status_code=404, detail="Produto não encontrado.")
    
    produto.preco_clube = novo_preco_clube
    db.commit()
    db.refresh(produto)
    return produto


# --- Relatórios e BI ---
def obter_metricas_bi(db: Session):
    total_produtos = db.query(models.Produto).count()
    total_clientes = db.query(models.Cliente).count()
    total_pedidos = db.query(models.Pedido).count()
    
    faturamento_total = db.query(func.coalesce(func.sum(models.Pedido.total), 0.0)).scalar()
    
    return {
        "total_produtos_cadastrados": total_produtos,
        "total_clientes_fidelidade": total_clientes,
        "total_pedidos_realizados": total_pedidos,
        "faturamento_total": float(faturamento_total)
    }


# --- Seções Promocionais ---
def criar_secao_promocional(db: Session, secao: schemas.SecaoPromocionalCreate):
    dados = secao.model_dump() if hasattr(secao, 'model_dump') else secao.dict()
    produto_ids = dados.pop("produto_ids", [])
    
    db_secao = models.SecaoPromocional(**dados)
    
    if produto_ids:
        produtos = db.query(models.Produto).filter(models.Produto.id.in_(produto_ids)).all()
        db_secao.produtos = produtos

    db.add(db_secao)
    db.commit()
    db.refresh(db_secao)
    return db_secao

def atualizar_secao_promocional(db: Session, secao_id: int, secao: schemas.SecaoPromocionalUpdate):
    db_secao = db.query(models.SecaoPromocional).filter(models.SecaoPromocional.id == secao_id).first()
    if not db_secao:
        return None

    dados = secao.model_dump(exclude_unset=True) if hasattr(secao, 'model_dump') else secao.dict(exclude_unset=True)
    produto_ids = dados.pop("produto_ids", None)

    for chave, valor in dados.items():
        setattr(db_secao, chave, valor)

    if produto_ids is not None:
        produtos = db.query(models.Produto).filter(models.Produto.id.in_(produto_ids)).all()
        db_secao.produtos = produtos

    db.commit()
    db.refresh(db_secao)
    return db_secao

def listar_secoes_ativas(db: Session):
    return (
        db.query(models.SecaoPromocional)
        .filter(models.SecaoPromocional.ativa == True)
        .order_by(models.SecaoPromocional.ordem.asc())
        .all()
    )

def reordenar_secoes(db: Session, reordenacoes: List[schemas.SecaoReordenarItem]):
    for item in reordenacoes:
        db.query(models.SecaoPromocional).filter(models.SecaoPromocional.id == item.id).update({"ordem": item.ordem})
    db.commit()
    return True

def deletar_secao_promocional(db: Session, secao_id: int):
    db_secao = db.query(models.SecaoPromocional).filter(models.SecaoPromocional.id == secao_id).first()
    if db_secao:
        db.delete(db_secao)
        db.commit()
        return True
    return False