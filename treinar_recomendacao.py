import pandas as pd
from sqlalchemy import create_engine
from sqlalchemy import text

# ATENÇÃO: Usamos 'postgresql+psycopg' para compatibilidade com a versão 3 do driver
SQLALCHEMY_DATABASE_URL ="postgresql://neondb_owner:npg_Lhqa3Bmfinc8@ep-hidden-lake-b6g4vju2-pooler.c-2.sa-east-1.aws.neon.tech/neondb?sslmode=require&channel_binding=require"

def treinar_motor_recomendacao():
    try:
        engine = create_engine(
            SQLALCHEMY_DATABASE_URL,
            connect_args={"client_encoding": "utf8"}
        )
        
        # 1. Carrega os itens dos pedidos armazenados no PostgreSQL
        # Buscando o histórico de vendas para treinar a IA
        # Buscando o histórico de vendas para treinar a IA
        query = """
        SELECT i.pedido_id, i.produto_id, p.nome, p.categoria_id, p.preco 
        FROM itens_pedido i
        JOIN produtos p ON i.produto_id = p.id
    """
    
        with engine.connect() as conn:
        # Executa a consulta nativamente pelo SQLAlchemy
            resultado = conn.execute(text(query))
        
        # Constrói o DataFrame manualmente com os dados e os nomes das colunas
        df_itens = pd.DataFrame(resultado.fetchall(), columns=resultado.keys())

        if df_itens.empty:
            print("⚠️ A tabela 'itens_pedido' está vazia. Cadastre pedidos para treinar a IA.")
            return

        # 2. Cruza os dados para identificar compras conjuntas
        df_pares = pd.merge(
            df_itens, 
            df_itens, 
            on='pedido_id', 
            suffixes=('_a', '_b')
        )

        # 3. Filtra autoreferências
        df_pares = df_pares[df_pares['produto_id_a'] != df_pares['produto_id_b']]

        if df_pares.empty:
            print("⚠️ É necessário ter pedidos com pelo menos 2 produtos para gerar combinações.")
            return

        # 4. Agrupa e calcula a frequência de compras casadas
        coocorrencias = (
            df_pares
            .groupby(['produto_id_a', 'produto_id_b'])
            .size()
            .reset_index(name='frequencia')
        )

        # 5. Salva/Sobrescreve a matriz na tabela 'recomendacoes_ia'
        with engine.begin() as conn:
            # Salvar o modelo treinado no banco de dados passando a URL em texto
            coocorrencias.to_sql(
            'recomendacoes_ia', 
            con=str(engine.url), # 👈 Passamos a string de conexão diretamente
            if_exists='replace', 
            index=False
    )

        print("✅ Treinamento concluído e matriz de inteligência salva na tabela 'recomendacoes_ia'!")
        print("\nTop combinações gravadas:")
        print(coocorrencias.head(10))

    except Exception as e:
        print(f"❌ Erro ao treinar a IA: {e}")

if __name__ == "__main__":
    treinar_motor_recomendacao()