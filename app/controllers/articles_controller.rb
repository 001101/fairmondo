class ArticlesController < InheritedResources::Base

  respond_to :html

  # Create is safed by denail!
  before_filter :authenticate_user!, :except => [:show, :index, :autocomplete, :sunspot_failure]

  before_filter :build_login , :unless => :user_signed_in?, :only => [:show,:index, :sunspot_failure]

  before_filter :setup_template_select, :only => [:new]

  before_filter :setup_categories, :only => [:index]

  actions :all, :except => [ :create, :destroy ] # inherited methods

  #Sunspot Autocomplete
  def autocomplete
    search = Sunspot.search(Article) do
      fulltext params[:keywords] do
        fields(:title)
      end
    end
    @titles = []
    search.hits.each do |hit|
      title = hit.stored(:title).first
      @titles.push(title)
    end
    render :json => @titles
  rescue Errno::ECONNREFUSED
    render :json => []
    end

  def index
    @search_cache = Article.new(params[:article])
    ######## Solr
    begin
      s = search(@search_cache)
      @articles = s.results
    ########
    rescue Errno::ECONNREFUSED
      @articles = policy_scope(Article).paginate :page => params[:page], :per_page=>12
      render_hero :action => "sunspot_failure"
    end

    index!
  end



  def show
    @article = Article.find(params[:id])
    authorize @article
    if @article.active
      setup_recommendations
    else
      if policy(@article).activate?
      @article.calculate_fees_and_donations
      end
    end
    set_title_image_and_thumbnails

    # find fair alternative
    @alternative = nil
    if !@article.fair && params[:article]
      query = Article.new(params[:article])
      query.fair = true
      @alternative = get_alternative query
      if !@alternative
        query.fair = false
        query.ecologic = true
        @alternative = get_alternative query
        if !@alternative
          query.ecologic = false
          query.condition = :old
          @alternative = get_alternative query
        end
      end
    end

    show!
  end




  def new
    if !current_user.valid?
      flash[:error] = t('article.notices.incomplete_profile')
      redirect_to edit_user_registration_path
    return
    end
    ############### From Template ################
    if template_id = params[:template_select] && params[:template_select][:article_template]
      if template_id.present?
        @applied_template = ArticleTemplate.find(template_id)
        @article = Article.new(@applied_template.deep_article_attributes, :without_protection => true)
        # Make copies of the images
        @article.images = []
        @applied_template.article.images.each do |image|
          copyimage = Image.new
          copyimage.image = image.image
          @article.images << copyimage
        end
        save_images
        flash.now[:notice] = t('template_select.notices.applied', :name => @applied_template.name)
      else
        flash.now[:error] = t('template_select.errors.article_template_missing')
        @article = Article.new
      end
    else
    #############################################
      @article = Article.new
    end
    @article.seller = current_user
    authorize @article
    setup_form_requirements
    new!

  end

  def edit

    @article = Article.find(params[:id])
    authorize @article
    setup_form_requirements
    edit!
  end

  def create # Still needs Refactoring
    @article = current_user.articles.build(params[:article])

    authorize @article

    # Check if we can save the article

    if @article.save && build_and_save_template(@article)

      if @article.category_proposal.present?
        ArticleMailer.category_proposal(@article.category_proposal).deliver
      end

      respond_to do |format|
        format.html { redirect_to article_path(@article) }
        format.json { render :json => @article, :status => :created, :location => @article }
      end

    else
      save_images
      respond_to do |format|
        setup_form_requirements
        format.html { render :action => "new" }
        format.json { render :json => @article.errors, :status => :unprocessable_entity }
      end
    end
  end

  def update # Still needs Refactoring

     @article = Article.find(params[:id])
     authorize @article
     if @article.update_attributes(params[:article]) && build_and_save_template(@article)
       respond_to do |format|
          format.html { redirect_to @article, :notice => (I18n.t 'article.notices.update') }
          format.json { head :no_content }
       end
     else
       save_images
       setup_form_requirements
       respond_to do |format|
         format.html { render :action => "edit" }
         format.json { render :json => @article.errors, :status => :unprocessable_entity }
       end
     end

  end

  def activate

      @article = Article.find(params[:id])
      authorize @article
      @article.calculate_fees_and_donations
      @article.locked = true # Lock The Article
      @article.active = true # Activate to be searchable
      @article.save

      update! do |success, failure|
        success.html { redirect_to @article, :notice => I18n.t('article.notices.create') }
        failure.html {
                      setup_form_requirements
                      render :action => :edit
                     }
      end


  end

  def deactivate
      @article = Article.find(params[:id])
      authorize @article
      @article.active = false # Activate to be searchable
      @article.save

      update! do |success, failure|
        success.html {  redirect_to @article, :notice => I18n.t('article.notices.deactivated') }
        failure.html {
                      #should not happen!
                      setup_form_requirements
                      render :action => :edit
                     }
      end
  end

  def report
    @text = params[:report]
    @article = Article.find(params[:id])
    if @text != ""
      ArticleMailer.report_article(@article,@text).deliver
      redirect_to @article, :notice => (I18n.t 'article.actions.reported')
    else
      redirect_to @article, :notice => (I18n.t 'article.actions.reported-error')
    end
  end


  ##### Private Helpers


  private

  def search(query)
    search = Sunspot.search(Article) do
      fulltext query.title
      paginate :page => params[:page], :per_page=>12
      with :fair, true if query.fair
      with :ecologic, true if query.ecologic
      with :small_and_precious, true if query.small_and_precious
      with :condition, query.condition if query.condition
      with :category_ids, Article::Categories.search_categories(query.categories) if query.categories.present?
    end
    search
  end

  def get_alternative query
    begin
      s = search(query)
      alternatives = s.results

      if alternatives
        if alternatives.first != @article
          return alternatives.first
        else
          if alternatives[1]
            return alternatives[1]
          end
        end
      end
    rescue Errno::ECONNREFUSED

    end
    nil
  end

  def setup_template_select
    @article_templates = ArticleTemplate.where(:user_id => current_user.id)
  end

  def setup_recommendations
    @libraries = @article.libraries.public.paginate(:page => params[:page], :per_page=>10)
    @seller_products = @article.seller.articles.paginate(:page => params[:page], :per_page=>18)
  end

  def set_title_image_and_thumbnails
    if params[:image]
      @title_image = Image.find(params[:image])
    else
      @title_image = @article.images[0]
    end
    @thumbnails = @article.images
    @thumbnails.reject!{|image| image.id == @title_image.id} if @title_image #Reject the selected image from
  end

  ################## Form #####################
  def setup_form_requirements
    setup_transaction
    setup_categories
    build_questionnaires
    build_template
  end

  def setup_transaction
    @article.build_transaction
  end

  def build_questionnaires
    @article.build_fair_trust_questionnaire unless @article.fair_trust_questionnaire
    @article.build_social_producer_questionnaire unless @article.social_producer_questionnaire
  end

  def build_template
    unless @article_template
      if params[:article_template]
        @article_template = ArticleTemplate.new(params[:article_template])
      else
        @article_template = ArticleTemplate.new
      end
    end
  end


  ########## build Template #################
  def build_and_save_template(article)
    if template_attributes = params[:article_template]
      if template_attributes[:save_as_template] && template_attributes[:name].present?
        template_attributes[:article_attributes] = params[:article]
        @article_template = ArticleTemplate.new(template_attributes)
        @article_template.article.images.clear
        article.images.each do |image|
          copyimage = Image.new
          copyimage.image = image.image
          @article_template.article.images << copyimage
          copyimage.save
        end

      @article_template.user = article.seller
      @article_template.save
      else
      true
      end
    else
    true
    end
  end

  ############ Save Images ################

  def save_images
    #At least try to save the images -> not persisted in browser
    if @article
      @article.images.each do |image|
        image.save
      end
    end
  end

  ################## Inherited Resources
  protected

  def collection
    @libraries ||= policy_scope(Article)
  end

end

