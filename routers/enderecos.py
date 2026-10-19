import requests

def buscar_lat_long_nominatim(rua: str, numero: str, cidade: str, estado: str, cep: str):
    """Consulta a API do Nominatim (OpenStreetMap) para obter latitude e longitude."""
    url = "https://nominatim.openstreetmap.org/search"
    
    # Monta a string de endereço formatada para busca
    query = f"{rua}, {numero}, {cidade} - {estado}, {cep}, Brasil"
    
    params = {
        'q': query,
        'format': 'json',
        'limit': 1
    }
    
    # ⚠️ ATENÇÃO: O Nominatim exige obrigatoriamente um User-Agent personalizado nas requisições
    headers = {
        'User-Agent': 'BoxSmartApp/1.0 (contato@boxsmart.com)'
    }
    
    try:
        response = requests.get(url, params=params, headers=headers, timeout=5)
        if response.status_code == 200:
            data = response.json()
            if data and len(data) > 0:
                lat = float(data[0]['lat'])
                lon = float(data[0]['lon'])
                return lat, lon
    except Exception as e:
        print(f"[GEOCODING ERROR] Falha ao conectar com o serviço de geocodificação: {e}")
        
    return None, None