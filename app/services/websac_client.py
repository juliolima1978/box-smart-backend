import httpx
import asyncio
import uuid
from datetime import datetime
from typing import List, Dict, Any, Optional

class WebSacIntegration:
    def __init__(self, cnpj: str, token: str, dominio: str = "controlware"):
        self.base_url = f"http://{dominio}.websac.net/v3/api"
        self.headers = {
            "cnpj": cnpj,
            "token": token
        }
        # URL base onde ficam hospedadas as fotos nomeadas com o código de barras (EAN.png)
        self.url_base_imagens = "https://seu-storage.com.br/imagens"

    async def _request(self, method: str, endpoint: str, data: Optional[Dict] = None, params: Optional[Dict] = None) -> Any:
        url = f"{self.base_url}{endpoint}"
        async with httpx.AsyncClient(timeout=30.0) as client:
            if method.upper() == "GET":
                response = await client.get(url, headers=self.headers, params=params)
            elif method.upper() == "POST":
                response = await client.post(url, headers=self.headers, data=data)
            else:
                raise ValueError("Método HTTP não suportado")

            response.raise_for_status()
            
            try:
                return response.json()
            except ValueError:
                return response.text

    # =======================================================
    # 🛒 1. SINCRONIZAÇÃO DE PRODUTOS E CATÁLOGO
    # =======================================================

    async def sincronizar_catalogo(self) -> List[Dict[str, Any]]:
        """
        Busca todos os produtos ativos do WebSac lidando com a paginação de 500 em 500 itens.
        """
        produtos_totais = []
        pagina_atual = 1
        limite_por_pagina = 500

        print("🔄 [WebSac] Iniciando sincronização de catálogo...")

        while True:
            try:
                params = {
                    "pagina": pagina_atual,
                    "ativo": "true"
                }
                
                produtos_pagina = await self._request("GET", "/produto/listar", params=params)
                
                if not isinstance(produtos_pagina, list):
                    break

                produtos_totais.extend(produtos_pagina)

                if len(produtos_pagina) < limite_por_pagina:
                    print(f"✅ [WebSac] Sincronização concluída. Total: {len(produtos_totais)} produtos.")
                    break
                
                pagina_atual += 1
                await asyncio.sleep(0.3)

            except Exception as e:
                print(f"❌ [WebSac] Erro na paginação {pagina_atual}: {e}")
                break

        return self._formatar_produtos_boxsmart(produtos_totais)

    def _formatar_produtos_boxsmart(self, produtos_websac: list) -> List[Dict[str, Any]]:
        produtos_formatados = []
        
        for prod in produtos_websac:
            if not prod.get("ativo", True):
                continue

            gtin_list = prod.get("gtin", [])
            codigo_barras = str(gtin_list[0]).strip() if gtin_list else None

            preco_normal = float(prod.get("preco_varejo", 0.0))
            preco_oferta = float(prod.get("preco_varejo_oferta", 0.0))
            preco_clube = preco_oferta if (0 < preco_oferta < preco_normal) else None

            peso_variavel = prod.get("peso_variavel", False)
            embalagem = prod.get("embalagem_venda", {})
            unidade = "KG" if peso_variavel else embalagem.get("unidade", "UN")

            depto = prod.get("departamento", {})
            imagem_url = f"{self.url_base_imagens}/{codigo_barras}.png" if codigo_barras else None

            produtos_formatados.append({
                "id_websac": prod.get("id"),
                "nome": prod.get("descricao_resumida") or prod.get("descricao_completa"),
                "codigo_barras": codigo_barras,
                "preco": preco_normal,
                "preco_clube": preco_clube,
                "estoque": float(prod.get("estoque_atual", 0.0)),
                "unidade": unidade,
                "peso_variavel": peso_variavel,
                "categoria_id": depto.get("id"),
                "categoria_nome": depto.get("descricao"),
                "imagem_url": imagem_url,
                "ativo": True
            })
            
        return produtos_formatados

    # =======================================================
    # 📦 2. INJEÇÃO DE PEDIDOS DE VENDA
    # =======================================================

    def _gerar_xml_venda(self, pedido_app: dict, dominio: str = "31404041000177") -> str:
        id_sessao = str(uuid.uuid4()).upper()
        
        # Itens do pedido montados na estrutura tbMovSessoesValores
        itens_xml = ""
        for index, item in enumerate(pedido_app.get("itens", []), start=1):
            id_valor = str(uuid.uuid4()).upper()
            preco_item = item.get("preco_efetivo", 0.0)
            qtd_item = item.get("quantidade", 1)
            valor_total_item = preco_item * qtd_item
            
            itens_xml += f"""
            <tbMovSessoesValores 
                mov_idValor="{id_valor}" 
                mov_idSessao="{id_sessao}" 
                mov_idPag="{index}" 
                mov_idOperador="2" 
                mov_tpLancamento="2" 
                mov_vLanc="{valor_total_item:.2f}" 
                mov_idResponsavel="2" 
                mov_obs="Produto ID {item.get('produto_id')}" 
                sys_idInsert="2" 
                sys_dInsert="{datetime.now().isoformat()}"
            />"""

        xml = f"""<?xml version="1.0"?><xmlIntegracao><Dominio>{dominio}</Dominio><IdLoja>1</IdLoja><IdCaixa>99</IdCaixa><NumCaixa>99</NumCaixa><ArquivoXml><root><tbMovSessoes mov_idSessao="{id_sessao}" mov_idCaixa="99" cai_numCaixa="99" cai_chave="{str(uuid.uuid4())}" sys_idInsert="2" sys_dInsert="{datetime.now().isoformat()}" sys_idUpdate="2" sys_dUpdate="{datetime.now().isoformat()}"/>{itens_xml}</root></ArquivoXml><ChaveTerminal>64</ChaveTerminal><TpLanc>2</TpLanc><TpArqXml>2</TpArqXml></xmlIntegracao>"""
        return xml.strip()

    async def enviar_pedido_websac(self, pedido_app: dict, cod_estabelec: int = 1):
        id_saurusvenda = str(uuid.uuid4())
        xml_montado = self._gerar_xml_venda(pedido_app)
        
        payload = {
            "idsaurusvenda": id_saurusvenda,
            "codestabelec": cod_estabelec,
            "arqxml": xml_montado,
            "tipoarquivoxml": 2,
            "caixa": 99,
            "cupom": pedido_app.get("id", 1001),
            "processado": "N",
            "tipolancamento": 2,
            "nomearquivo": f"boxsmart_pedido_{pedido_app.get('id')}.xml",
            "dtmovto": datetime.now().strftime("%Y-%m-%d")
        }

        return await self._request("POST", "/saurusvenda", data=payload)