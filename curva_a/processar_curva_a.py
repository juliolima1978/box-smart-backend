import asyncio
import re
import pandas as pd
import httpx


# ------------------------------------------------------------------
# 0. LEITURA E LOCALIZAÇÃO AUTOMÁTICA DO CABEÇALHO DO WEBSAC
# ------------------------------------------------------------------
def carregar_relatorio_websac(caminho_arquivo: str) -> pd.DataFrame:
    """
    Carrega o relatório do WebSac e localiza automaticamente a linha
    real do cabeçalho da tabela, descartando títulos e metadados do ERP.
    """
    df_raw = None
    
    # 1. Tenta ler como HTML (formato padrão do WebSac)
    try:
        tabelas = pd.read_html(caminho_arquivo, encoding="utf-8")
        if tabelas:
            df_raw = tabelas[0]
    except Exception:
        try:
            tabelas = pd.read_html(caminho_arquivo, encoding="latin1")
            if tabelas:
                df_raw = tabelas[0]
        except Exception:
            pass

    # 2. Fallbacks de leitura (Excel / CSV)
    if df_raw is None:
        try:
            df_raw = pd.read_excel(caminho_arquivo, engine="xlrd")
        except Exception:
            try:
                df_raw = pd.read_excel(caminho_arquivo, engine="openpyxl")
            except Exception:
                df_raw = pd.read_csv(caminho_arquivo, sep=None, engine="python", encoding="latin1")

    # 3. Localiza a linha do cabeçalho real
    linha_cabecalho = None
    for idx, row in df_raw.iterrows():
        valores_linha = " ".join([str(v).upper() for v in row.values if pd.notna(v)])
        if any(term in valores_linha for term in ["CODIGO", "CÓDIGO", "DESCRICAO", "DESCRIÇÃO", "EAN", "PRODUTO"]):
            linha_cabecalho = idx
            break

    if linha_cabecalho is not None:
        # Promove a linha encontrada a cabeçalho do DataFrame
        novas_colunas = [str(c).strip().upper() for c in df_raw.iloc[linha_cabecalho].values]
        df = df_raw.iloc[linha_cabecalho + 1:].copy()
        df.columns = novas_colunas
    else:
        df = df_raw.copy()
        df.columns = [str(c).strip().upper() for c in df.columns]

    df = df.dropna(how="all").reset_index(drop=True)
    return df


# ------------------------------------------------------------------
# 1. MAPEAMENTO DE IMAGENS DE FALLBACK POR CATEGORIA
# ------------------------------------------------------------------
IMAGENS_CATEGORIA_FALLBACK = {
    "AÇOUGUE": "https://i.imgur.com/8Qp4Z9m.png",
    "HORTIFRUTI": "https://i.imgur.com/2XyZ1vK.png",
    "PADARIA": "https://i.imgur.com/3YwX5tL.png",
    "BEBIDAS": "https://i.imgur.com/4ZvW6uM.png",
    "LIMPEZA": "https://i.imgur.com/5AuY7vN.png",
    "MERCEARIA": "https://i.imgur.com/6BtX8wO.png",
    "FRIOS E LATICINIOS": "https://i.imgur.com/7CwY9xP.png",
    "GERAL": "https://i.imgur.com/6tJyuYb.png"
}

def obter_imagem_fallback(nome_categoria: str) -> str:
    cat = str(nome_categoria).strip().upper() if nome_categoria else "GERAL"
    for chave, url in IMAGENS_CATEGORIA_FALLBACK.items():
        if chave in cat:
            return url
    return IMAGENS_CATEGORIA_FALLBACK["GERAL"]


def formatar_ean(val) -> str | None:
    """Formatador para converter floats/strings para um EAN-13 limpo."""
    if pd.isna(val) or val is None:
        return None
    val_str = str(val).strip()
    if "." in val_str:
        val_str = val_str.split(".")[0]
    val_limpo = re.sub(r'\D', '', val_str)
    
    # Se tiver 12 dígitos, adiciona o zero à esquerda (EAN-13 padrão Brasil)
    if len(val_limpo) == 12:
        val_limpo = "0" + val_limpo
        
    if len(val_limpo) >= 8:
        return val_limpo
    return None


# ------------------------------------------------------------------
# 2. CONSULTA DE IMAGEM VIA EAN (OPEN FOOD FACTS API)
# ------------------------------------------------------------------
async def buscar_imagem_por_ean(client: httpx.AsyncClient, ean: str) -> str | None:
    """Consulta a API do Open Food Facts para obter o URL da foto pelo EAN-13."""
    ean_limpo = formatar_ean(ean)
    if not ean_limpo:
        return None

    url = f"https://world.openfoodfacts.org/api/v0/product/{ean_limpo}.json"
    try:
        response = await client.get(url, timeout=5.0)
        if response.status_code == 200:
            data = response.json()
            if data.get("status") == 1:
                product = data.get("product", {})
                return product.get("image_front_url") or product.get("image_url")
    except Exception:
        pass
    return None


# ------------------------------------------------------------------
# 3. LEITURA DO RELATÓRIO E PROCESSAMENTO COMPLETO
# ------------------------------------------------------------------
async def processar_relatorio_abc(caminho_excel: str) -> pd.DataFrame:
    df = carregar_relatorio_websac(caminho_excel)
    
    print(f"📌 Colunas identificadas no relatório: {list(df.columns)}")

    # Identificação flexível das colunas no relatório
    col_ean = next((c for c in df.columns if "EAN" in c or "BARRA" in c or "GTIN" in c), None)
    col_id = next((c for c in df.columns if "COD" in c or "ID" in c or "PLU" in c), None)
    col_nome = next((c for c in df.columns if "NOME" in c or "DESC" in c or "PRODUTO" in c), None)
    col_cat = next((c for c in df.columns if "CAT" in c or "DEP" in c or "SECAO" in c), None)
    col_curva = next((c for c in df.columns if "CURVA" in c or "ABC" in c), None)

    print(f"🔍 Colunas Mapeadas -> EAN: '{col_ean}' | ID: '{col_id}' | Nome: '{col_nome}' | Categoria: '{col_cat}'")

    if col_curva and col_curva in df.columns:
        df_curva_a = df[df[col_curva].astype(str).str.upper().str.contains("A")].copy()
    else:
        df_curva_a = df.head(500).copy()

    print(f"📊 Processando {len(df_curva_a)} produtos da Curva A...")

    resultados = []
    
    async with httpx.AsyncClient(headers={"User-Agent": "BoxSmartApp - Integration/1.0"}) as client:
        for idx, row in df_curva_a.iterrows():
            id_websac = row[col_id] if col_id else idx
            nome = row[col_nome] if col_nome else ""
            ean_raw = row[col_ean] if col_ean else None
            categoria = row[col_cat] if col_cat else "GERAL"
            
            imagem_url = await buscar_imagem_por_ean(client, ean_raw)
            
            origem_imagem = "EAN_API"
            if not imagem_url:
                imagem_url = obter_imagem_fallback(categoria)
                origem_imagem = "FALLBACK_CATEGORIA"

            resultados.append({
                "id_websac": id_websac,
                "nome": nome,
                "ean": formatar_ean(ean_raw),
                "categoria": categoria,
                "imagem_url": imagem_url,
                "origem_imagem": origem_imagem
            })

    df_resultado = pd.DataFrame(resultados)
    
    total_ean = len(df_resultado[df_resultado["origem_imagem"] == "EAN_API"])
    total_fallback = len(df_resultado[df_resultado["origem_imagem"] == "FALLBACK_CATEGORIA"])
    print(f"✅ Concluído! Fotos encontradas por EAN: {total_ean} | Usando Fallback: {total_fallback}")
    
    return df_resultado


# ------------------------------------------------------------------
# EXECUÇÃO
# ------------------------------------------------------------------
if __name__ == "__main__":
    from datetime import datetime
    
    caminho_ficheiro = "ABC de Vendas de 01_09_2026 a 30_09_2026.xls"
    df_mapeado = asyncio.run(processar_relatorio_abc(caminho_ficheiro))
    
    nome_arquivo_saida = "produtos_curva_a_imagens.csv"
    
    try:
        df_mapeado.to_csv(nome_arquivo_saida, index=False, encoding="utf-8-sig")
        print(f"📁 Ficheiro '{nome_arquivo_saida}' gerado com sucesso!")
    except PermissionError:
        # Se o arquivo estiver aberto no Excel, gera um arquivo alternativo com timestamp
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        nome_alt = f"produtos_curva_a_imagens_{timestamp}.csv"
        df_mapeado.to_csv(nome_alt, index=False, encoding="utf-8-sig")
        print(f"⚠️ O arquivo '{nome_arquivo_saida}' estava aberto no Excel.")
        print(f"📁 Resultado salvo com sucesso em: '{nome_alt}'")