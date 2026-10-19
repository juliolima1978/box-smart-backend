import math
from typing import Optional
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from database import get_db
import models

router = APIRouter(prefix="/api/frete", tags=["Frete"])

# Coordenadas da Loja Base em Itatiba-SP
LOJA_LAT = -23.0062
LOJA_LON = -46.8403

def calcular_distancia_haversine(lat1, lon1, lat2, lon2):
    """Calcula a distância em quilômetros entre dois pontos geográficos."""
    R = 6371.0
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = math.sin(dlat / 2)**2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon / 2)**2
    c = 2 * math.asin(math.sqrt(a))
    return R * c

@router.get("/calcular")
def calcular_frete(
    subtotal: float = Query(0.0),
    endereco_id: Optional[int] = Query(None),
    db: Session = Depends(get_db)
):
    # 1. Busca configurações gerais de frete
    config = db.query(models.ConfigFrete).first()
    taxa_padrao = getattr(config, 'taxa_padrao', 8.99) if config else 8.99
    valor_minimo = getattr(config, 'valor_minimo_frete_gratis', 300.00) if config else 300.00
    frete_gratis_hoje = getattr(config, 'frete_gratis_hoje', False) if config else False

    if frete_gratis_hoje:
        return {"valor_frete": 0.0, "motivo": "Frete grátis hoje no Box Smart! 🎉", "faltam_para_frete_gratis": 0.0}

    if valor_minimo and subtotal >= valor_minimo:
        return {"valor_frete": 0.0, "motivo": f"Frete grátis garantido para compras acima de R$ {valor_minimo:.2f}!", "faltam_para_frete_gratis": 0.0}

    taxa_calculada = taxa_padrao

    # 2. Se o ID do endereço foi enviado, calculamos a distância
    if endereco_id:
        endereco = db.query(models.Endereco).filter(models.Endereco.id == endereco_id).first()
        if endereco and endereco.latitude and endereco.longitude:
            print(f"[FRETE DEBUG] Calculando distância para o Endereço ID {endereco_id} (Lat: {endereco.latitude}, Lon: {endereco.longitude})")
            distancia_km = calcular_distancia_haversine(LOJA_LAT, LOJA_LON, endereco.latitude, endereco.longitude)
            print(f"[FRETE DEBUG] Distância da loja até o cliente: {distancia_km:.2f} km")
            
            # Exemplo de regra de preço por km (R$ 7 base até 5km, + R$ 1.50 por km extra)
            if distancia_km > 5.0:
                km_extra = distancia_km - 5.0
                taxa_calculada = taxa_padrao + 5.01 #(km_extra * 1.50)
            
            taxa_calculada = round(taxa_calculada, 2)
        else:
            print(f"[FRETE DEBUG] Endereço ID {endereco_id} encontrado, mas sem latitude/longitude mapeadas.")

    faltam = round(valor_minimo - subtotal, 2) if valor_minimo and subtotal < valor_minimo else 0.0

    return {
        "valor_frete": taxa_calculada,
        "taxa_padrao": taxa_padrao,
        "valor_minimo_frete_gratis": valor_minimo,
        "frete_gratis_hoje": False,
        "motivo": "Taxa calculada por distância" if endereco_id else "Taxa padrão de entrega",
        "faltam_para_frete_gratis": faltam
    }