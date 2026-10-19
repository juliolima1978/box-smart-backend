from datetime import datetime
from zoneinfo import ZoneInfo
from sqlalchemy import Column, Integer, String, Float, ForeignKey, Text, Boolean, DateTime, Table
from sqlalchemy.orm import relationship
from database import Base

# 🌟 Função utilitária de Fuso Horário de Brasília (UTC-3)
FUSO_BRASILIA = ZoneInfo("America/Sao_Paulo")

def agora_brasilia():
    return datetime.now(FUSO_BRASILIA)


# 🌟 Tabela de associação para relacionamento N:N entre Seção Promocional e Produtos
secao_produto = Table(
    "secao_produto",
    Base.metadata,
    Column("secao_id", Integer, ForeignKey("secoes_promocionais.id", ondelete="CASCADE"), primary_key=True),
    Column("produto_id", Integer, ForeignKey("produtos.id", ondelete="CASCADE"), primary_key=True)
)


class Endereco(Base):
    __tablename__ = "enderecos"
    
    id = Column(Integer, primary_key=True, index=True)
    cliente_id = Column(Integer, ForeignKey("clientes.id"))
    rua = Column(String, nullable=False)
    numero = Column(String, nullable=False)
    complemento = Column(String, nullable=True)
    bairro = Column(String, nullable=False)
    cidade = Column(String, nullable=False)
    uf = Column(String, nullable=False)
    cep = Column(String, nullable=False)
    padrao = Column(Boolean, default=False)
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)
    cliente = relationship("Cliente", back_populates="enderecos")


class SecaoPromocional(Base):
    __tablename__ = "secoes_promocionais"

    id = Column(Integer, primary_key=True, index=True)
    titulo = Column(String(250), nullable=False)
    tipo = Column(String(50), nullable=False)  # Ex: 'grade_produtos', 'banner_secundario', 'carrossel'
    ordem = Column(Integer, default=0)
    ativa = Column(Boolean, default=True)
    banner_url = Column(String(500), nullable=True)
    categoria_id = Column(Integer, nullable=True)
    
    acao_tipo = Column(String, nullable=True)
    acao_valor = Column(String, nullable=True)

    # 🌟 Relacionamento com produtos selecionados manualmente
    produtos = relationship("Produto", secondary=secao_produto, back_populates="secoes")

    @property
    def produto_ids(self):
        return [p.id for p in self.produtos] if self.produtos else []


class Categoria(Base):
    __tablename__ = "categorias"
    
    id = Column(Integer, primary_key=True, index=True)
    nome = Column(String(100), unique=True, index=True, nullable=False)
    imagem_url = Column(String, nullable=True)
    cor_icone = Column(String, nullable=True)
    cor_fundo = Column(String, nullable=True)
    cor_texto = Column(String, nullable=True)
    ativo = Column(Boolean, default=True)
    ordem = Column(Integer, default=0)
    
    produtos = relationship("Produto", back_populates="categoria")
    subcategorias = relationship("Subcategoria", back_populates="categoria", cascade="all, delete-orphan")


class Subcategoria(Base):
    __tablename__ = "subcategorias"
    
    id = Column(Integer, primary_key=True, index=True)
    nome = Column(String(100), index=True, nullable=False)
    categoria_id = Column(Integer, ForeignKey("categorias.id"), nullable=False)
    ativo = Column(Boolean, default=True)
    ordem = Column(Integer, default=0)
    
    categoria = relationship("Categoria", back_populates="subcategorias")
    produtos = relationship("Produto", back_populates="subcategoria")


class Produto(Base):
    __tablename__ = "produtos"
    
    id = Column(Integer, primary_key=True, index=True)
    nome = Column(String(150), index=True, nullable=False)
    descricao = Column(Text, nullable=True)
    preco = Column(Float, nullable=False)
    preco_clube = Column(Float, nullable=True)
    estoque = Column(Integer, default=0)
    categoria_id = Column(Integer, ForeignKey("categorias.id"))
    subcategoria_id = Column(Integer, ForeignKey("subcategorias.id"), nullable=True) 
    imagem_url = Column(String, nullable=True)
    ativo = Column(Boolean, default=True)
    mais_vendido = Column(Boolean, default=False)
    destaque = Column(Boolean, default=False)
    unidade = Column(String, default="un")
    
    categoria = relationship("Categoria", back_populates="produtos")
    subcategoria = relationship("Subcategoria", back_populates="produtos")
    secoes = relationship("SecaoPromocional", secondary=secao_produto, back_populates="produtos")


class Cliente(Base):
    __tablename__ = "clientes"
    
    id = Column(Integer, primary_key=True, index=True)
    nome = Column(String(150), nullable=False)
    email = Column(String(150), unique=True, index=True, nullable=False)
    senha_hash = Column(String(255), nullable=False)
    telefone = Column(String(20), nullable=True)
    endereco = Column(String, nullable=True)
    cpf = Column(String, nullable=True)
    is_admin = Column(Boolean, default=False)
    perfil = Column(String(50), default="cliente") # 'cliente', 'admin', 'separador', 'entregador'
    eh_membro_clube = Column(Boolean, default=False)
    ativo = Column(Boolean, default=True)
    fcm_token = Column(String, nullable=True)

    fidelidade = relationship("Fidelidade", back_populates="cliente", uselist=False)
    enderecos = relationship("Endereco", back_populates="cliente")
    reset_token = Column(String, nullable=True)
    reset_token_expires = Column(DateTime, nullable=True)


class Fidelidade(Base):
    __tablename__ = "fidelidade"
    
    id = Column(Integer, primary_key=True, index=True)
    cliente_id = Column(Integer, ForeignKey("clientes.id"), unique=True)
    pontos = Column(Integer, default=0)
    nivel = Column(String(50), default="Bronze")
    
    cliente = relationship("Cliente", back_populates="fidelidade")


class Banner(Base):
    __tablename__ = "banners"
    
    id = Column(Integer, primary_key=True, index=True)
    titulo = Column(String(150), nullable=False)
    imagem_url = Column(String(255), nullable=False)
    ativo = Column(Boolean, default=True)
    data_criacao = Column(DateTime(timezone=True), default=agora_brasilia)
    tipo = Column(String, default="principal")
    ordem = Column(Integer, default=0)
    acao_tipo = Column(String(50), nullable=True)
    acao_valor = Column(String(255), nullable=True)


class Pedido(Base):
    __tablename__ = "pedidos"
    
    id = Column(Integer, primary_key=True, index=True)
    cliente_id = Column(Integer, ForeignKey("clientes.id"), nullable=False)
    separador_id = Column(Integer, ForeignKey("clientes.id"), nullable=True)
    entregador_id = Column(Integer, ForeignKey("clientes.id"), nullable=True)
    entregador_nome = Column(String, nullable=True)
    total = Column(Float, nullable=False)
    status = Column(String(50), default="PENDENTE")
    separado_por = Column(String, nullable=True)
    endereco_entrega = Column(String, nullable=True)
    motivo_cancelamento = Column(Text, nullable=True)
    latitude_entregador = Column(Float, nullable=True)
    longitude_entregador = Column(Float, nullable=True)
    
    # Pagamento e Cobrança
    forma_pagamento = Column(String, nullable=True)
    troco_para = Column(Float, default=0.0)
    esta_pago = Column(Boolean, default=False)
    codigo_confirmacao = Column(String(10), nullable=True)
    taxa_entrega = Column(Float, default=0.0)
    subtotal = Column(Float, default=0.0)
    total = Column(Float, nullable=False)
    
    # Timestamps de Rastreabilidade Operacional (Horário de Brasília)
    data_criacao = Column(DateTime(timezone=True), default=agora_brasilia)
    data_inicio_separacao = Column(DateTime(timezone=True), nullable=True)
    data_separado = Column(DateTime(timezone=True), nullable=True)
    data_saiu_entrega = Column(DateTime(timezone=True), nullable=True)
    data_concluido = Column(DateTime(timezone=True), nullable=True)
    data_cancelado = Column(DateTime(timezone=True), nullable=True)

    # Relacionamentos
    cliente = relationship("Cliente", foreign_keys=[cliente_id])
    separador = relationship("Cliente", foreign_keys=[separador_id])
    entregador = relationship("Cliente", foreign_keys=[entregador_id])
    itens = relationship("ItemPedido", back_populates="pedido", cascade="all, delete-orphan")


class ItemPedido(Base):
    __tablename__ = "itens_pedido"

    id = Column(Integer, primary_key=True, index=True)
    pedido_id = Column(Integer, ForeignKey("pedidos.id"))
    produto_id = Column(Integer, ForeignKey("produtos.id"))
    quantidade = Column(Float, nullable=False)
    preco_unitario = Column(Float, nullable=False)

    # Relacionamentos
    pedido = relationship("Pedido", back_populates="itens")
    produto = relationship("Produto")

    @property
    def nome(self):
        return self.produto.nome if self.produto else None

    @property
    def imagem_url(self):
        return self.produto.imagem_url if self.produto else None

    @property
    def categoria_nome(self):
        if self.produto and self.produto.categoria:
            return self.produto.categoria.nome
        return "Mercearia / Geral"


class Notificacao(Base):
    __tablename__ = "notificacoes"
    
    id = Column(Integer, primary_key=True, index=True)
    cliente_id = Column(Integer, ForeignKey("clientes.id"), nullable=True)
    titulo = Column(String(150), nullable=False)
    mensagem = Column(Text, nullable=False)
    data_envio = Column(DateTime(timezone=True), default=agora_brasilia)
    lida = Column(Boolean, default=False)
    tipo = Column(String(50), default="pedido")
    
    cliente = relationship("Cliente")


class RecomendacaoIA(Base):
    __tablename__ = "recomendacoes_ia"

    produto_id_a = Column(Integer, primary_key=True) 
    produto_id_b = Column(Integer, primary_key=True)
    frequencia = Column(Integer)


class Favorito(Base):
    __tablename__ = "favoritos"
    
    id = Column(Integer, primary_key=True, index=True)
    cliente_id = Column(Integer, ForeignKey("clientes.id"), nullable=False)
    produto_id = Column(Integer, ForeignKey("produtos.id"), nullable=False)
    data_criacao = Column(DateTime(timezone=True), default=agora_brasilia)
    
    cliente = relationship("Cliente")
    produto = relationship("Produto")


class ConfigBoxPrime(Base):
    __tablename__ = "config_box_prime"

    id = Column(Integer, primary_key=True, index=True)
    titulo_topo = Column(String, default="Clube Box Prime")
    subtitulo = Column(String, default="Exclusividade e vantagens criadas para você.")
    historia = Column(Text)
    beneficios_json = Column(Text)
    
class ConfigFrete(Base):
    __tablename__ = "config_frete"

    id = Column(Integer, primary_key=True, index=True)
    taxa_padrao = Column(Float, default=7.00)                      # Ex: R$ 7,00
    valor_minimo_frete_gratis = Column(Float, default=100.00)     # Ex: Frete grátis acima de R$ 100,00
    frete_gratis_hoje = Column(Boolean, default=False)             # Promoção "Hoje o frete é grátis"