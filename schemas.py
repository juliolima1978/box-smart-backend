from pydantic import BaseModel, EmailStr
from typing import Optional, List
from datetime import datetime
from pydantic import Field
from datetime import date



# ==========================================
# 📂 ENDEREÇOS
# ==========================================
class EnderecoCreate(BaseModel):
    cep: str
    rua: str
    numero: str
    bairro: str
    cidade: str
    estado: str
    latitude: Optional[float] = None
    longitude: Optional[float] = None
# ==========================================
# 📂 SEÇÕES PROMOCIONAIS & CURATORIA
# ==========================================
class SecaoPromocionalBase(BaseModel):
    titulo: str
    tipo: str  # Ex: 'grade_produtos', 'banner_secundario', 'carrossel'
    ordem: Optional[int] = 0
    ativa: Optional[bool] = True
    banner_url: Optional[str] = None
    categoria_id: Optional[int] = None
    acao_tipo: Optional[str] = None
    acao_valor: Optional[str] = None
    produto_ids: Optional[List[int]] = [] # 🌟 IDs dos produtos escolhidos a dedo

class SecaoPromocionalCreate(SecaoPromocionalBase):
    pass

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

class SecaoPromocionalResponse(SecaoPromocionalBase):
    id: int
    class Config:
        from_attributes = True

class SecaoReordenarItem(BaseModel):
    id: int
    ordem: int


# ==========================================
# 📂 CATEGORIAS & DEPARTAMENTOS
# ==========================================
class CategoriaBase(BaseModel):
    nome: str
    ativo: Optional[bool] = True
    ordem: Optional[int] = 0

class CategoriaCreate(CategoriaBase):
    imagem_url: Optional[str] = None
    cor_icone: Optional[str] = None
    cor_fundo: Optional[str] = None
    cor_texto: Optional[str] = None

class CategoriaUpdate(BaseModel):
    nome: Optional[str] = None
    imagem_url: Optional[str] = None
    cor_icone: Optional[str] = None
    cor_fundo: Optional[str] = None
    cor_texto: Optional[str] = None
    ativo: Optional[bool] = None
    ordem: Optional[int] = None

class CategoriaResponse(CategoriaBase):
    id: int
    imagem_url: Optional[str] = None
    cor_icone: Optional[str] = None
    cor_fundo: Optional[str] = None
    cor_texto: Optional[str] = None

    class Config:
        from_attributes = True


# ==========================================
# 📂 SUBCATEGORIAS
# ==========================================
class SubcategoriaBase(BaseModel):
    nome: str
    categoria_id: int
    ativo: Optional[bool] = True
    ordem: Optional[int] = 0

class SubcategoriaCreate(SubcategoriaBase):
    pass

class SubcategoriaResponse(SubcategoriaBase):
    id: int

    class Config:
        from_attributes = True


# ==========================================
# 📂 PRODUTOS
# ==========================================
class ProdutoBase(BaseModel):
    nome: str
    descricao: Optional[str] = None
    preco: float
    preco_clube: Optional[float] = None
    estoque: int = 0
    categoria_id: Optional[int] = None
    subcategoria_id: Optional[int] = None
    imagem_url: Optional[str] = None
    ativo: Optional[bool] = True
    mais_vendido: Optional[bool] = False
    destaque: Optional[bool] = False
    unidade: Optional[str] = "un"

class ProdutoCreate(ProdutoBase):
    pass

class ProdutoUpdate(BaseModel):
    nome: Optional[str] = None
    descricao: Optional[str] = None
    preco: Optional[float] = None
    preco_clube: Optional[float] = None
    estoque: Optional[int] = None
    categoria_id: Optional[int] = None
    subcategoria_id: Optional[int] = None
    imagem_url: Optional[str] = None
    ativo: Optional[bool] = None
    mais_vendido: Optional[bool] = None
    destaque: Optional[bool] = None
    unidade: Optional[str] = None

class ProdutoResponse(ProdutoBase):
    id: int

    class Config:
        from_attributes = True


# ==========================================
# 📂 NOTIFICAÇÕES
# ==========================================
class NotificacaoCreate(BaseModel):
    titulo: str
    mensagem: str
    cliente_id: Optional[int] = None  # Se nulo, envia para todos os membros
    tipo: Optional[str] = "alerta"

class NotificacaoOut(BaseModel):
    id: int
    titulo: str
    mensagem: str
    data_envio: Optional[datetime] = None
    cliente_id: Optional[int] = None
    lida: bool = False
    tipo: str = "pedido"

    class Config:
        from_attributes = True


# ==========================================
# 📂 FIDELIDADE E USUÁRIOS
# ==========================================
class FidelidadeResponse(BaseModel):
    pontos: int
    nivel: str

    class Config:
        from_attributes = True

class ClienteBase(BaseModel):
    nome: str
    email: str
    telefone: Optional[str] = None
    cpf: Optional[str] = None
    perfil: Optional[str] = "cliente"  # 'cliente', 'admin', 'separador', 'entregador'
    ativo: Optional[bool] = True

class ClienteCreate(BaseModel):
    nome: str = Field(..., min_length=3, description="Nome completo do cliente")
    email: EmailStr
    senha: str = Field(..., min_length=6, description="Senha de acesso")
    telefone: str = Field(..., description="Telefone / WhatsApp principal")
    cpf: Optional[str] = Field(None, description="CPF para nota fiscal")
    cep: Optional[str] = Field(None, description="CEP de entrega principal")
    rua: Optional[str] = Field(None, description="Logradouro")
    numero: Optional[str] = Field(None, description="Número do endereço")
    bairro: Optional[str] = Field(None, description="Bairro")
    data_nascimento: Optional[date] = Field(None, description="Para campanhas do clube")

class ClienteResponse(ClienteBase):
    id: int
    is_admin: bool
    perfil: str
    ativo: bool = True
    fidelidade: Optional[FidelidadeResponse] = None

    class Config:
        from_attributes = True

class ClienteResumoResponse(BaseModel):
    id: int
    nome: str
    email: str
    telefone: Optional[str] = None
    endereco: Optional[str] = None

    class Config:
        from_attributes = True

class UsuarioCreate(BaseModel):
    nome: str
    email: str
    senha: str
    perfil: Optional[str] = "separador"
    telefone: Optional[str] = None
    ativo: Optional[bool] = True


# ==========================================
# 🔑 AUTENTICAÇÃO / LOGIN
# ==========================================
class LoginRequest(BaseModel):
    email: str
    senha: str

class TokenResponse(BaseModel):
    access_token: str
    token_type: str
    perfil: Optional[str] = "cliente"
    nome: Optional[str] = None
    is_admin: Optional[bool] = False


# ==========================================
# 📂 PEDIDOS E CARRINHO
# ==========================================
class ItemCarrinho(BaseModel):
    produto_id: int
    quantidade: float
    preco_unitario: float = 0.0

class PedidoCreate(BaseModel):
    cliente_id: Optional[int] = None
    itens: List[ItemCarrinho]
    opcao_substituicao: Optional[str] = None
    deseja_cpf_nota: Optional[bool] = False
    endereco_entrega: Optional[str] = None
    forma_pagamento: Optional[str] = "Dinheiro na Entrega"
    troco_para: Optional[float] = 0.0
    cupom_codigo: Optional[str] = None
    valor_desconto_cupom: Optional[float] = 0.0
    esta_pago: Optional[bool] = False
    valor_subtotal: float = 0.0 # 👈 ISSO PRECISA EXISTIR AQUI
    taxa_entrega: float = 0.0   # 👈 ISSO PRECISA EXISTIR AQUI
    valor_total: float = 0.0

class ItemPedidoResponse(BaseModel):
    id: int
    produto_id: int
    nome: Optional[str] = None
    quantidade: int
    preco_unitario: float
    imagem_url: Optional[str] = None
    categoria_nome: Optional[str] = None

    class Config:
        from_attributes = True

class AtualizarStatusRequest(BaseModel):
    status: str
    motivo_cancelamento: Optional[str] = None
    separado_por: Optional[str] = None
    separador_id: Optional[int] = None
    codigo_confirmacao: Optional[str] = None

class PedidoResponse(BaseModel):
    id: int
    cliente_id: int
    cliente: Optional[ClienteResumoResponse] = None
    separador_id: Optional[int] = None
    separado_por: Optional[str] = None
    entregador_id: Optional[int] = None
    entregador_nome: Optional[str] = None
    total: float
    status: str
    opcao_substituicao: Optional[str] = None
    deseja_cpf_nota: Optional[bool] = False
    endereco_entrega: Optional[str] = None
    
    forma_pagamento: Optional[str] = "Dinheiro na Entrega"
    troco_para: Optional[float] = 0.0
    esta_pago: Optional[bool] = False
    codigo_confirmacao: Optional[str] = None

    data_criacao: datetime
    data_separado: Optional[datetime] = None
    data_saiu_entrega: Optional[datetime] = None
    data_concluido: Optional[datetime] = None
    
    itens: List[ItemPedidoResponse] = []

    class Config:
        from_attributes = True


# ==========================================
# 📂 BANNERS ADMINISTRATIVOS
# ==========================================
class BannerCreate(BaseModel):
    titulo: str
    imagem_url: str
    ativo: bool = True
    tipo: Optional[str] = "principal"
    ordem: Optional[int] = 0
    acao_tipo: Optional[str] = None
    acao_valor: Optional[str] = None

class BannerResponse(BaseModel):
    id: int
    titulo: str
    imagem_url: str
    ativo: bool
    data_criacao: datetime
    tipo: Optional[str] = "principal"
    ordem: Optional[int] = 0  # 👈 ADICIONADO: Garante a devolução da ordem nas respostas da API
    acao_tipo: Optional[str] = None
    acao_valor: Optional[str] = None

    class Config:
        from_attributes = True


# ==========================================
# 📂 PREÇO CLUBE
# ==========================================
class PrecoClubeUpdate(BaseModel):
    preco_clube: float