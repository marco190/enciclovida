class Pez < ActiveRecord::Base

  self.table_name = "#{CONFIG.bases.pez}.peces"
  self.primary_key = 'especie_id'

  has_many :peces_criterios, :class_name => 'PezCriterio', :foreign_key => :especie_id, dependent: :destroy
  has_many :criterios, :through => :peces_criterios, :source => :criterio
  has_many :criterio_propiedades, :through => :criterios, :source => :propiedad

  has_many :peces_propiedades, :class_name => 'PezPropiedad', :foreign_key => :especie_id
  has_many :propiedades, :through => :peces_propiedades, :source => :propiedad

  belongs_to :especie
  has_one :adicional, :through => :especie, :source => :adicional

  scope :select_joins_peces, -> { select([:nombre_comun_principal, :valor_total, :valor_zonas, :imagen, :con_estrella]).
      select("peces.especie_id, #{Especie.table_name}.#{Especie.attribute_alias(:nombre_cientifico)} AS nombre_cientifico") }

  scope :filtros_peces, -> { select_joins_peces.distinct.left_joins(:criterios, :peces_propiedades, :adicional).
      order(con_estrella: :desc, valor_total: :asc, tipo_imagen: :asc).order("#{Especie.table_name}.#{Especie.attribute_alias(:nombre_cientifico)} ASC") }

  scope :nombres_peces, -> { select([:especie_id, :nombre_cientifico, :nombres_comunes])}
  scope :nombres_cientificos_peces, -> { select(:especie_id).select("nombre_cientifico as label")}
  scope :nombres_comunes_peces, -> { select(:especie_id).select("nombres_comunes as label")}

  attr_accessor :guardar_manual, :anio, :valor_por_zona

  validates_presence_of :especie_id
  before_save :actualiza_pez, unless: :guardar_manual
  after_save :guarda_valor_zonas_y_total, unless: :guardar_manual

  accepts_nested_attributes_for :peces_criterios, reject_if: :all_blank, allow_destroy: true
  accepts_nested_attributes_for :peces_propiedades, reject_if: :all_blank, allow_destroy: true

  GRUPOS_PECES_MARISCOS = %w(Actinopterygii Chondrichthyes Cnidaria Echinodermata Mollusca Mollusca Crustacea)

  # REVISADO: Corre los metodos necesarios para actualizar el pez
  def actualiza_pez
    guarda_nom_iucn
    asigna_imagen
    guarda_redis
    asigna_valor_zonas_y_total
  end

  # REVISADO: Guarda el redis del pez aprovechando el metodo empaquetado de especie
  def guarda_redis
    especie.guarda_redis(loader: 'peces', foto_principal: imagen)
  end

  # REVISADO: Actualiza todos los servicios
  def self.actualiza_todo
    all.each do |p|
      p.guardar_manual = true
      p.actualiza_pez
      p.save if p.changed?
    end
  end

  # REVISADO: Asigna los valores promedio por zona, de acuerdo a cada estado
  def guarda_valor_zonas_y_total
    asigna_valor_zonas_y_total
    self.guardar_manual = true
    save if valid?
  end

  # REVISADO: Asigna los valores promedio por zona, de acuerdo a todos los criterios
  def asigna_valor_zonas_y_total
    asigna_anio
    valores_por_zona

    criterio_propiedades.select('propiedades.*, valor').cnp.where('anio=?', anio).each do |propiedad|
      zona_num = propiedad.parent.nombre_zona_a_numero  # Para obtener la posicion de la zona

      if propiedad.nombre_propiedad == 'No se distribuye'  # Quitamos la zona
        self.valor_por_zona[zona_num] = 'n'
      elsif propiedad.nombre_propiedad == 'Estatus no definido' # La zona se muestra en gris
        #self.valor_por_zona[zona_num] = 's'  # Por si se arrepienten
      else
        self.valor_por_zona[zona_num] = valor_por_zona[zona_num] + propiedad.valor
      end
    end

    self.valor_zonas = valor_zona_a_color.join('')
    self.valor_total = color_zona_a_valor.inject(:+)
  end

  # REVISADO: Actualiza todas las zonas y valores totales de todos los peces
  def self.actualiza_todo_valor_zonas_y_total
    all.each do |p|
      p.guardar_manual = true
      p.guarda_valor_zonas_y_total
    end
  end

  # REVISADO: Asigna los valores de la nom de acuerdo a catalogos
  def guarda_nom_iucn
    asigna_anio
    criterio_id = 158

    # Para actualizar o crear el valor de la nom
    if nom = especie.catalogos.nom.first
      if prop = Propiedad.where(nombre_propiedad: nom.descripcion).first
        if crit = prop.criterios.where('anio=?', 2012).first
          criterio_id = crit.id
        end
      end
    end

    if crit = criterios.where('anio=?', 2012).nom.first
      pez_crit = peces_criterios.where(criterio_id: crit.id).first
      pez_crit.criterio_id = criterio_id
    else
      pez_crit = peces_criterios.new
      pez_crit.criterio_id = criterio_id # No aplica
    end

    pez_crit.save if pez_crit.changed?

    # Para actualizar o crear el valor de iucn
    criterio_id = 159

    if iucn = especie.catalogos.iucn.first
      if prop = Propiedad.where(nombre_propiedad: iucn.descripcion).first
        if crit = prop.criterios.where('anio=?', 2012).first
          criterio_id = crit.id
        end
      end
    end

    if crit = criterios.where('anio=?', 2012).iucn.first
      pez_crit = peces_criterios.where(criterio_id: crit.id).first
      pez_crit.criterio_id = criterio_id
    else
      pez_crit = peces_criterios.new
      pez_crit.criterio_id = criterio_id # No aplica
    end

    pez_crit.save if pez_crit.changed?
  end

  # REVISADO: Actualiza las categorias de riesgo de todos los peces
  def self.actualiza_todo_nom_iucn
    all.each do |p|
      p.guardar_manual = true
      p.guarda_nom_iucn
    end
  end

  # REVISADO: Guarda la imagen asociada del pez
  def guarda_imagen
    asigna_imagen
    save if changed?
  end

  # REVISADO: Asigna la ilustracion, foto o ilustracion, asi como el tipo de foto
  def asigna_imagen
    # Trata de asignar la ilustracion
    bdi = BDIService.new
    res = bdi.dameFotos(taxon: especie, campo: 528, autor: 'Sergio de la Rosa Martínez', autor_campo: 80, ilustraciones: true)

    if res[:estatus]
      if res[:fotos].any?
        self.imagen = res[:fotos].first.medium_url
        self.tipo_imagen = 1
        return
      end
    end

    # Trata de asignar la foto principal
    if a = adicional
      foto = a.foto_principal

      if foto.present?
        self.imagen = foto
        self.tipo_imagen = 2
        return
      end
    end

    # Asigna el grupo iconico de la especie
    especie.ancestors.reverse.map(&:nombre_cientifico).each do |nombre|
      if Busqueda::GRUPOS_ANIMALES.include?(nombre.strip)
        self.imagen = "#{nombre.estandariza}-ev-icon"
        self.tipo_imagen = 3
        return
      end
    end

    # Asignar la silueta, el ultimo caso, ya que es una silueta general
    self.imagen = '/assets/app/peces/silueta.png'
    self.tipo_imagen = 4
  end

  # REVISADO: Actualiza la imagen principal de todos los peces
  def self.actualiza_todo_imagen
    all.each do |p|
      p.guardar_manual = true
      p.guarda_imagen
    end
  end


  private

  # REVISADO: Asocia el valor por zona a un color correspondiente
  def valor_zona_a_color
    valor_por_zona.each_with_index do |zona, i|
      next unless zona.class == Integer # Por si ya tiene asignada una letra

      case zona
      when -5..4
        self.valor_por_zona[i] = 'v'
      when 5..19
        self.valor_por_zona[i] = 'a'
      when 20..100
        self.valor_por_zona[i] = 'r'
      end
    end
  end

  # REVISADO: Este valor es solo de referencia para el valor total
  def color_zona_a_valor
    zonas = []

    valor_zonas.split('').each do |zona|
      case zona
      when 'v'
        zonas << -100
      when 'a'
        zonas << 10
      when 'r'
        zonas << 100
      when 'n', 's'
        zonas << 0
      end
    end

    zonas
  end

  # REVISADO: Para sacar solo el año en cuestion
  def asigna_anio
    self.anio = anio || CONFIG.peces.anio || 2012
  end

  # REVISADO: El valor de los criterios sin la CNP
  def valores_por_zona
    asigna_anio
    valor = 0

    propiedades = criterio_propiedades.select('valor').where('anio=?', anio)
    valor+= propiedades.tipo_capturas.map(&:valor).inject(:+).to_i
    valor+= propiedades.tipo_vedas.map(&:valor).inject(:+).to_i
    valor+= propiedades.procedencias.map(&:valor).inject(:+).to_i
    valor+= propiedades.nom.map(&:valor).inject(:+).to_i
    valor+= propiedades.iucn.map(&:valor).inject(:+).to_i

    # Para asignar el campo con_estrella que se asocia a las pesquerias sustentables
    pesquerias = propiedades.pesquerias.map(&:valor).inject(:+).to_i
    valor+= pesquerias
    self.con_estrella = 1 if pesquerias != 0

    self.valor_por_zona = Array.new(6, valor)
  end
end