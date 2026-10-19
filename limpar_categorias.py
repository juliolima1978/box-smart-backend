from database import SessionLocal
import models

db = SessionLocal()
try:
    categorias = db.query(models.Categoria).all()
    vistas = {}
    
    for cat in categorias:
        nome_limpo = cat.nome.strip().upper()
        if nome_limpo in vistas:
            # Já existe uma categoria com este nome! Vamos migrar os produtos para a oficial e apagar a duplicada.
            categoria_oficial_id = vistas[nome_limpo]
            print(f"🔄 Unificando categoria duplicada '{cat.nome}' (ID {cat.id}) para a oficial (ID {categoria_oficial_id})...")
            
            # Atualiza os produtos que estavam na duplicada
            db.query(models.Produto).filter(models.Produto.categoria_id == cat.id).update(
                {"categoria_id": categoria_oficial_id}
            )
            # Remove a categoria duplicada
            db.delete(cat)
        else:
            vistas[nome_limpo] = cat.id
            # Padroniza o nome para maiúsculo
            if cat.nome != nome_limpo:
                cat.nome = nome_limpo

    db.commit()
    print("✅ Categorias unificadas e limpas com sucesso no PostgreSQL!")
except Exception as e:
    db.rollback()
    print(f"❌ Erro ao limpar categorias: {e}")
finally:
    db.close()