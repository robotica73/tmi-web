class CodebooksController < ApplicationController

  USERS = { ENV['GENERAL_ADMISSION_USERNAME'] => ENV['GENERAL_ADMISSION_PASSWORD'] }

  before_action :authenticate

  def authenticate
    authenticate_or_request_with_http_digest("Application") do |name|
      USERS[name]
    end
  end

  def index
    @contexts = Question::QUESTIONS
  end

  def show
    @context = params[:id]
    @context_key = @context.gsub("_given","").gsub("_exp","").gsub("klass","class").gsub("_","-")
    @enqueued_at = params[:enqueued_at].present? ? Time.at(params[:enqueued_at].to_i).strftime("%T %Z") : nil

    sections = Question::QUESTIONS.keys
    @section_name = Question::QUESTIONS[@context.gsub("class","klass").to_sym]
    
    # These modulo gymnastics allow the previous/next arrows to wrap around
    previous_index = (sections.index(@context.gsub("class","klass").to_sym) - 1) % sections.length
    next_index = (sections.index(@context.gsub("class","klass").to_sym) + 1) % sections.length
    @previous_section = sections[previous_index]
    @next_section = sections[next_index]

    if params[:id].split('_').last == "given"
      @frequencies = Identity.histogram(@context)
    else
      @frequencies = Code.histogram(@context)
    end

    if @context.include?("_exp") || @context.include?("_feel")
      @categories_histogram = Category.histogram(@context_key)
      @total_codes = @categories_histogram.values.sum
    end

  end

  def enqueue_categories
    context = params[:codebook_id].gsub("_given","").gsub("_exp","").gsub("klass","class").gsub("_","-")
    CategoryExtractorJob.perform_async(context)
    redirect_to( action: :show, id: params[:codebook_id], params: {enqueued_at: Time.now.strftime("%s")} )
  end

end
