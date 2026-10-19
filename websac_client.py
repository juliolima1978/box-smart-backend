import httpx
import asyncio

class WebSacIntegration:
    def __init__(self, cnpj: str = "44737674000149", token: str = "ba2e4041-0d3d-4ed5-a110-df9ca841102c", dominio: str = "tescarollo"):
        self.base_url = f"http://{dominio}.websac.net/v3/api"
        self.headers = {
            "cnpj": str(cnpj),   # Garante que seja tratado como string
            "token": str(token)
        }
    async def sincronizar_catalogo(self) -> list:
        """
        Busca o catálogo completo de produtos do WebSac usando paginação.
        """
        produtos_totais = []
        pagina_atual = 1
        limite_por_pagina = 500

        print("🔄 [WebSac] Conectando e baixando catálogo completo...")
        async with httpx.AsyncClient(timeout=30.0) as client:
            while True:
                try:
                    params = {"pagina": pagina_atual, "ativo": "true"}
                    response = await client.get(
                        f"{self.base_url}/produto/listar", 
                        headers=self.headers, 
                        params=params
                    )
                    response.raise_for_status()
                    produtos_pagina = response.json()

                    if not isinstance(produtos_pagina, list) or not produtos_pagina:
                        break

                    produtos_totais.extend(produtos_pagina)
                    print(f"📦 Página {pagina_atual} obtida ({len(produtos_pagina)} produtos). Total acumulado: {len(produtos_totais)}")

                    if len(produtos_pagina) < limite_por_pagina:
                        break
                    
                    pagina_atual += 1
                    await asyncio.sleep(0.2)
                except Exception as e:
                    print(f"❌ Erro na paginação do WebSac (página {pagina_atual}): {e}")
                    break

        print(f"✅ Download finalizado! Total bruto obtido do WebSac: {len(produtos_totais)} produtos.")
        return produtos_totais