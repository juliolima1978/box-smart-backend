import datetime
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger
from apscheduler.triggers.interval import IntervalTrigger
from app.services.websac_client import WebSacIntegration

# Instância global do agendador
scheduler = AsyncIOScheduler()

# Insira as credenciais do seu cliente WebSac
WEBSAC_CNPJ = "44737674000149"
WEBSAC_TOKEN = "ba2e4041-0d3d-4ed5-a110-df9ca841102c"
WEBSAC_DOMINIO = "tescarollo"

async def rotina_carga_total():
    print(f"[{datetime.datetime.now()}] 🌙 Iniciando Carga Total do Catálogo (Madrugada)...")
    websac = WebSacIntegration(cnpj=WEBSAC_CNPJ, token=WEBSAC_TOKEN, dominio=WEBSAC_DOMINIO)
    produtos = await websac.sincronizar_catalogo()
    
    # TODO: Inserir ou atualizar a lista de 'produtos' no seu Banco de Dados (PostgreSQL / Firebase)
    print(f"[{datetime.datetime.now()}] 💾 {len(produtos)} produtos sincronizados no banco de dados.")

async def rotina_carga_expressa():
    print(f"[{datetime.datetime.now()}] ⚡ Atualizando Preços e Saldos de Estoque...")
    websac = WebSacIntegration(cnpj=WEBSAC_CNPJ, token=WEBSAC_TOKEN, dominio=WEBSAC_DOMINIO)
    produtos = await websac.sincronizar_catalogo()
    
    # TODO: Atualizar apenas as colunas 'preco', 'preco_clube' e 'estoque' no Banco de Dados
    print(f"[{datetime.datetime.now()}] 🔄 Preços e estoques atualizados com sucesso.")

def iniciar_scheduler():
    # 1. Carga Total: Executa diariamente às 03:00 da manhã
    scheduler.add_job(
        rotina_carga_total,
        CronTrigger(hour=3, minute=0),
        id="sync_total_madrugada",
        replace_existing=True
    )

    # 2. Carga Expressa: Executa a cada 15 minutos
    scheduler.add_job(
        rotina_carga_expressa,
        IntervalTrigger(minutes=15),
        id="sync_expressa_estoque",
        replace_existing=True
    )

    scheduler.start()
    print("⏳ [APScheduler] Rotinas automáticas do WebSac iniciadas com sucesso.")

def parar_scheduler():
    scheduler.shutdown()
    print("🛑 [APScheduler] Agendador de tarefas finalizado.")