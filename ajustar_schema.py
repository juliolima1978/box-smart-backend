from sqlalchemy import text
from database import engine

def ajustar_tabela_produtos():
    print("🔧 Verificando e adicionando a coluna 'ean' na tabela 'produtos'...")
    with engine.begin() as conn:
        conn.execute(text("""
            ALTER TABLE produtos ADD COLUMN IF NOT EXISTS ean VARCHAR(50);
            ALTER TABLE produtos ADD COLUMN IF NOT EXISTS categoria VARCHAR(100);
            ALTER TABLE produtos ADD COLUMN IF NOT EXISTS imagem_url TEXT;
            ALTER TABLE produtos ADD COLUMN IF NOT EXISTS ativo BOOLEAN DEFAULT True;
        """))
    print("✅ Tabela 'produtos' ajustada com sucesso!")

if __name__ == "__main__":
    ajustar_tabela_produtos()