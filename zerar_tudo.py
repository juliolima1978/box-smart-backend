import os
from sqlalchemy import text
from database import engine

import firebase_admin
from firebase_admin import credentials, firestore

# ------------------------------------------------------------------
# 1. LIMPEZA DO POSTGRESQL
# ------------------------------------------------------------------
def zerar_postgres():
    print("🐘 Zerando a tabela 'produtos' no PostgreSQL...")
    try:
        with engine.begin() as conn:
            conn.execute(text("TRUNCATE TABLE produtos RESTART IDENTITY CASCADE;"))
        print("✅ PostgreSQL zerado com sucesso!")
    except Exception as e:
        print(f"❌ Erro ao zerar PostgreSQL: {e}")


# ------------------------------------------------------------------
# 2. LIMPEZA DO FIREBASE FIRESTORE
# ------------------------------------------------------------------
def inicializar_firebase():
    if not firebase_admin._apps:
        cred_file = next(
            (f for f in ["serviceAccountKey.json", "firebase_credentials.json", "credentials.json"] if os.path.exists(f)),
            None
        )
        if cred_file:
            firebase_admin.initialize_app(credentials.Certificate(cred_file))
        else:
            firebase_admin.initialize_app()
    return firestore.client()


def zerar_firestore(db, nome_colecao="produtos", tamanho_lote=200):
    colecao_ref = db.collection(nome_colecao)
    docs = colecao_ref.limit(tamanho_lote).stream()
    deletados = 0

    for doc in docs:
        doc.reference.delete()
        deletados += 1

    if deletados >= tamanho_lote:
        return deletados + zerar_firestore(db, nome_colecao, tamanho_lote)
    return deletados


# ------------------------------------------------------------------
# 3. LIMPEZA DE ARQUIVOS DE CONTROLE LOCAL
# ------------------------------------------------------------------
def zerar_controle_local():
    arquivo = "enviados_curva_a.txt"
    if os.path.exists(arquivo):
        os.remove(arquivo)
        print(f"🧹 Arquivo de histórico '{arquivo}' removido.")


# ------------------------------------------------------------------
# EXECUÇÃO
# ------------------------------------------------------------------
if __name__ == "__main__":
    print("🚀 Iniciando reset total do ambiente...\n")
    
    # Executa a limpeza do PostgreSQL
    zerar_postgres()
    
    # Executa a limpeza do Firestore
    try:
        db = inicializar_firebase()
        print("🔥 Apagando coleção 'produtos' do Firebase Firestore...")
        total_fb = zerar_firestore(db, "produtos")
        print(f"✅ Firebase zerado com sucesso! ({total_fb} documentos removidos)")
    except Exception as e:
        print(f"❌ Erro ao zerar Firestore: {e}")

    # Remove o histórico de envio
    zerar_controle_local()
    
    print("\n✨ Ambiente 100% zerado e higienizado!")