import random
from datetime import datetime
from sqlalchemy.orm import Session
from database import engine
import models

with Session(engine) as db:
    produtos = db.query(models.Produto).all()
    clientes = db.query(models.Cliente).all()

    if not produtos or not clientes:
        print("❌ É necessário ter produtos e ao menos 1 cliente cadastrado no banco!")
        exit()

    print(f"📦 Encontrados {len(produtos)} produtos e {len(clientes)} clientes. Gerando histórico de vendas...")

    for i in range(20):
        cliente = random.choice(clientes)
        
        # Sorteia de 2 a 5 produtos diferentes por pedido
        qtd_produtos_no_pedido = random.randint(2, min(5, len(produtos)))
        produtos_sorteados = random.sample(produtos, k=qtd_produtos_no_pedido)
        
        itens_para_criar = []
        subtotal_pedido = 0.0

        # Prepara os itens e calcula os totais do pedido
        for prod in produtos_sorteados:
            e_pesavel = getattr(prod, 'variavel_por_peso', False) or (getattr(prod, 'unidade', '').lower() == 'kg')
            qtd = round(random.uniform(0.25, 1.5), 3) if e_pesavel else float(random.randint(1, 3))
            
            try:
                preco_num = float(str(prod.preco).replace(',', '.'))
            except Exception:
                preco_num = 10.0

            subtotal_item = round(preco_num * qtd, 2)
            subtotal_pedido += subtotal_item

            itens_para_criar.append({
                "produto_id": prod.id,
                "quantidade": qtd,
                "preco_unitario": preco_num
            })

        taxa_entrega = 7.00
        total_pedido = round(subtotal_pedido + taxa_entrega, 2)

        # Instancia o pedido com todos os valores obrigatórios preenchidos
        novo_pedido = models.Pedido(
            cliente_id=cliente.id,
            endereco_entrega="Endereço de Teste, 100",
            forma_pagamento=random.choice(["Pix", "Cartão na Entrega", "Dinheiro na Entrega"]),
            esta_pago=True,
            status="Concluído",
            subtotal=round(subtotal_pedido, 2),
            taxa_entrega=taxa_entrega,
            total=total_pedido,
            data_criacao=datetime.now()
        )
        db.add(novo_pedido)
        db.flush()  # Obtém o ID do pedido recém-criado

        # Grava os itens vinculados ao pedido
        for item_data in itens_para_criar:
            item = models.ItemPedido(
                pedido_id=novo_pedido.id,
                produto_id=item_data["produto_id"],
                quantidade=item_data["quantidade"],
                preco_unitario=item_data["preco_unitario"]
            )
            db.add(item)

    db.commit()
    print("✅ 20 pedidos fictícios criados com sucesso na tabela 'itens_pedido'!")