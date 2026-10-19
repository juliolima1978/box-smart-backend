import os
import asyncio
import pandas as pd
from sqlalchemy import text
from database import SessionLocal, engine
import models
import firebase_admin
from firebase_admin import credentials, firestore
from websac_client import WebSacIntegration

# Inicializa Firebase se necessário
if not firebase_admin._apps:
    if os.path.exists("serviceAccountKey.json"):
        firebase_admin.initialize_app(credentials.Certificate("serviceAccountKey.json"))

db_firestore = firestore.client()

def obter_ids_curva_a() -> set:
    """Lê os IDs da Curva A a partir do CSV."""
    caminhos = ["curva_a/produtos_curva_a_imagens.csv", "produtos_curva_a_imagens.csv"]
    for caminho in caminhos:
        if os.path.exists(caminho):
            df = pd.read_csv(caminho)
            if "id_websac" in df.columns:
                return set(pd.to_numeric(df["id_websac"], errors="coerce").dropna().astype(int).tolist())
    print("⚠️ Arquivo CSV da Curva A não encontrado. Processando todos os ativos.")
    return set()

def sanitizar_e_mapear(prod: dict) -> dict:
    """
    Trata rigorosamente cada campo, garantindo que pesáveis fiquem como 'kg' 
    e que nenhum campo crítico venha nulo.
    """
    # 1. Nome e Descrição
    nome = prod.get("descricao_resumida") or prod.get("descricao_completa") or prod.get("nome", "Produto")
    descricao = prod.get("descricao_completa") or nome

    # 2. Identificação de Produto Pesável (Crucial para Carnes, Frios, Hortifrúti)
    peso_variavel = bool(prod.get("peso_variavel", False))
    emb_venda = prod.get("embalagem_venda") or {}
    unidade_emb = str(emb_venda.get("unidade", "")).strip().upper()

    if peso_variavel or unidade_emb in ["KG", "KILO", "KILOGRAMA"]:
        unidade = "kg"
        eh_pesavel = True
    else:
        unidade = "un"
        eh_pesavel = False

    # 3. Estoque e Preços
    estoque = float(prod.get("estoque_atual", 0.0))
    if not eh_pesavel:
        estoque = int(estoque)
    
    preco = float(prod.get("preco_varejo", 0.0))
    preco_oferta = float(prod.get("preco_varejo_oferta", 0.0))
    
    # Correção do cálculo do preço clube / oferta
    preco_clube = preco_oferta if (0 < preco_oferta < preco) else None

    # 4. Código de Barras (EAN)
    gtin_list = prod.get("gtin", [])
    ean = str(gtin_list[0]).strip() if gtin_list else None

    # 5. Imagem baseada no EAN ou fallback
    imagem_url = f"https://seu-storage.com.br/imagens/{ean}.png" if ean else "https://i.imgur.com/6tJyuYb.png"

    # 6. Categoria (Departamento ou Grupo)
    depto = prod.get("departamento") or prod.get("grupo") or {}
    categoria = str(depto.get("descricao") or "GERAL").strip().upper()

    return {
        "id_websac": int(prod.get("id")),
        "nome": str(nome).strip().title(),
        "descricao": str(descricao).strip(),
        "preco": preco,
        "preco_clube": preco_clube,
        "unidade": unidade,
        "eh_pesavel": eh_pesavel,
        "estoque": max(0, estoque),
        "imagem_url": imagem_url,
        "categoria": categoria,
        "ativo": True if preco > 0 else False
    }

async def main():
    print("🚀 [Recomeço Limpo] Iniciando sincronização da Curva A...")
    
    # 1. Conecta ao WebSac
    websac = WebSacIntegration(cnpj="44737674000149", token="ba2e4041-0d3d-4ed5-a110-df9ca841102c", dominio="tescarollo")
    produtos_brutos = await websac.sincronizar_catalogo()

    # 2. Filtra Curva A
    ids_curva_a = obter_ids_curva_a()
    produtos_filtrados = [
        p for p in produtos_brutos 
        if not ids_curva_a or int(p.get("id", 0)) in ids_curva_a
    ]
    print(f"📊 Produtos selecionados da Curva A: {len(produtos_filtrados)}")

    # 3. Processa e grava no PostgreSQL e Firebase
    db = SessionLocal()
    try:
        batch_firestore = db_firestore.batch()
        contador_firestore = 0
        
        print("🐘 Gravando no PostgreSQL e Firestore...")
        for p_raw in produtos_filtrados:
            p = sanitizar_e_mapear(p_raw)
            
            # Garante Categoria no PostgreSQL
            cat_db = db.query(models.Categoria).filter(models.Categoria.nome == p["categoria"]).first()
            if not cat_db:
                cat_db = models.Categoria(nome=p["categoria"], ativo=True)
                db.add(cat_db)
                db.commit()
                db.refresh(cat_db)
            
            # Upsert Produto no PostgreSQL
            prod_db = db.query(models.Produto).filter(models.Produto.id == p["id_websac"]).first()
            if not prod_db:
                prod_db = models.Produto(id=p["id_websac"])
                db.add(prod_db)

            prod_db.nome = p["nome"]
            prod_db.descricao = p["descricao"]
            prod_db.preco = p["preco"]
            prod_db.preco_clube = p["preco_clube"]
            prod_db.unidade = p["unidade"]
            prod_db.estoque = p["estoque"]
            prod_db.imagem_url = p["imagem_url"]
            prod_db.categoria_id = cat_db.id
            prod_db.ativo = p["ativo"]

            # Prepara Firestore
            doc_ref = db_firestore.collection("produtos").document(str(p["id_websac"]))
            batch_firestore.set(doc_ref, {
                "id_websac": p["id_websac"],
                "nome": p["nome"],
                "descricao": p["descricao"],
                "preco": p["preco"],
                "preco_clube": p["preco_clube"],
                "unidade": p["unidade"],
                "eh_pesavel": p["eh_pesavel"],
                "estoque": p["estoque"],
                "imagem_url": p["imagem_url"],
                "categoria": p["categoria"],
                "ativo": p["ativo"]
            }, merge=True)
            
            contador_firestore += 1
            if contador_firestore % 400 == 0:
                batch_firestore.commit()
                batch_firestore = db_firestore.batch()

        db.commit()
        if contador_firestore % 400 != 0:
            batch_firestore.commit()

        print("✨ Sincronização limpa concluída com sucesso! Todos os pesáveis e campos mapeados perfeitamente.")
    except Exception as e:
        db.rollback()
        print(f"❌ Erro durante o processo: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    asyncio.run(main())