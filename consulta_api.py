from database import engine
from sqlalchemy import text

with engine.connect() as conn:
    # 📍 Atualiza o Endereço 2 com coordenadas distantes (> 5 km de Itatiba centro)
    conn.execute(text("""
        UPDATE enderecos 
        SET latitude = -22.9500, longitude = -46.8000 
        WHERE id = 2;
    """))
    conn.commit()
    print("Coordenadas do Endereço 2 atualizadas com sucesso!")