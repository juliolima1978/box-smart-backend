from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker

# ATENÇÃO: Usamos 'postgresql+psycopg' para compatibilidade com a versão 3 do driver
SQLALCHEMY_DATABASE_URL ="postgresql://neondb_owner:npg_Lhqa3Bmfinc8@ep-hidden-lake-b6g4vju2-pooler.c-2.sa-east-1.aws.neon.tech/neondb?sslmode=require&channel_binding=require" 
#"postgresql+psycopg://julio:tropper33@localhost:5432/box_smart_db"

engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    pool_pre_ping=True, 
    pool_recycle=300
    )
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()

# Dependência para injetar a sessão do banco nas rotas
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()