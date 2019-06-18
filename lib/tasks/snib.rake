namespace :snib do

  desc "Genera/actualiza las especies por estado de la base del SNIB y lo guarda en cache"
  task estados: :environment do
    Geoportal::Estado.all.each do |estado|
      Rails.logger.debug "[DEBUG] - Generando cache de especies con estado: #{estado.entidad}"
      br = BusquedaRegion.new
      br.params = { region_id: estado.entid, tipo_region: 'estado' }
      br.borra_cache_especies
      br.guarda_cache_especies
    end
  end

  desc "Genera/actualiza las especies por municipio de la base del SNIB y lo guarda en cache"
  task municipios: :environment do
    Geoportal::Municipio.all.each do |municipio|
      Rails.logger.debug "[DEBUG] - Generando cache de especies con municipio: #{estado.munid}"
      br = BusquedaRegion.new
      br.params = { region_id: municipio.munid, tipo_region: 'municipio' }
      br.borra_cache_especies
      br.guarda_cache_especies
    end
  end

  desc "Genera/actualiza las especies por ANP de la base del SNIB y lo guarda en cache"
  task anps: :environment do
    Geoportal::Anp.all.each do |anp|
      Rails.logger.debug "[DEBUG] - Generando cache de especies con ANP: #{anp.anpestid}"
      br = BusquedaRegion.new
      br.params = { region_id: anp.anpestid, tipo_region: 'anp' }
      br.borra_cache_especies
      br.guarda_cache_especies
    end
  end

  desc "Genera/actualiza las especies por estado, municipio y ANP de la base del SNIB y lo guarda en cache"
  task todos: :environment do
    regiones = %w(estado municipio anp)
    
    regiones.each do |region|
      "Geoportal::#{region.camelize}".constantize.all.each do |reg|
        Rails.logger.debug "[DEBUG] - Generando cache de especies con #{region.camelize}: #{reg.region_id}"
        br = BusquedaRegion.new
        br.params = { region_id: reg.region_id, tipo_region: region }
        br.borra_cache_especies
        br.guarda_cache_especies
      end
    end
  end

end