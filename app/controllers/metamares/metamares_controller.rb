class Metamares::MetamaresController < ApplicationController

  layout 'metamares'

  # La visualizacion por medio de D3
  def graficas
  end

  # Gráfica por año de publicacion contra campo de investigación
  def grafica1
    g = Metamares::GraficasM.new
    g.grafica1

    render json: g.datos
  end

  # Gráfica por área, region o localidad
  def grafica2
    g = Metamares::GraficasM.new(tipo_dato: [])
    g.grafica2

    render json: g.datos
  end

  # Busca una institucion por slug
  def dame_institucion
    i = Metamares::Institucion.new
    i.nombre_institucion = params[:nombre_institucion]

    respond_to do |format|
      format.json { render json: i.busca_institucion.map{ |i| { id: i.id, value: i.nombre_institucion } } }
      format.html { @institucion = i }
    end
  end
end
