class SiteController < ApplicationController
  def index
  end

  def search
    set_search_criteria

    @search_data = Search.all(@criteria)

    render "search/results"
  end

  def resource
    @resource = JSONModel(:resource).find(params[:id], :repo_id => params[:repo_id], "resolve[]" => ["subjects", "container_locations"])
    @repository = JSONModel(:repository).find(params[:repo_id])
    @tree = JSONModel(:resource_tree).find(nil, :resource_id => @resource.id, :repo_id => params[:repo_id])

    @breadcrumbs = [
      [@repository['repo_code'], url_for(:controller => :site, :action => :repository, :id => @repository.id), "repository"],
      [@resource.title, "#", "resource"]
    ]
  end

  def archival_object
    @archival_object = JSONModel(:archival_object).find(params[:id], :repo_id => params[:repo_id], "resolve[]" => ["subjects"])
    @resource = JSONModel(:resource).find_by_uri(@archival_object['resource']['ref'], :repo_id => params[:repo_id])
    @repository = JSONModel(:repository).find(params[:repo_id])
    @children = JSONModel::HTTP::get_json("/repositories/#{params[:repo_id]}/archival_objects/#{@archival_object.id}/children")

    @breadcrumbs = [
      [@repository['repo_code'], url_for(:controller => :site, :action => :repository, :id => @repository.id), "repository"],
      [@resource.title, url_for(:controller => :site, :action => :resource, :id => @resource.id, :repo_id => @repository.id), "resource"],
    ]

    ao = @archival_object
    while ao['parent'] do
      ao = JSONModel(:archival_object).find(JSONModel(:archival_object).id_for(ao['parent']['ref']), :repo_id => @repository.id)
      @breadcrumbs.push([ao.title, url_for(:controller => :site, :action => :archival_object, :id => ao.id, :repo_id => @repository.id), "archival_object"])
    end

    @breadcrumbs.push([@archival_object.title, "#", "archival_object"])
  end

  def repository
    if params[:repo_id].blank?
      @repositories = JSONModel(:repository).all
      return render "site/repositories"
    end

    set_search_criteria

    @repository = JSONModel(:repository).find(params[:repo_id])

    @breadcrumbs = [
      [@repository['repo_code'], url_for(:controller => :site, :action => :repository, :id => @repository.id), "repository"]
    ]

    @search_data = Search.repo(@repository.id, @criteria)

    render "search/results"
  end


  def location
    render "site/todo"
  end

  private

  def set_search_criteria
    @criteria = params.select{|k,v| ["page", "q", "type", "filter", "sort"].include?(k) and not v.blank?}

    @criteria["page"] ||= 1

    if @criteria["type"]
      @criteria["type[]"] = Array(@criteria["type"]).reject{|v| v.blank?}
      @criteria.delete("type")
    end

    if @criteria["filter"]
      @criteria["filter[]"] = Array(@criteria["filter"]).reject{|v| v.blank?}
      @criteria.delete("filter")
    end


    @criteria['type[]'] = Array(params[:type]) if not params[:type].blank?
    @criteria['exclude[]'] = params[:exclude] if not params[:exclude].blank?
    @criteria['facet[]'] = ["subjects", "primary_type"]
  
    # only allow locations, subjects, resources and archival objects in search results
    if params[:type].blank? or @criteria['type[]'].empty?
      @criteria['type[]'] = ['resource', 'archival_object']
    else
      @criteria['type[]'].keep_if {|t| ['resource', 'archival_object', 'location', 'subject'].include?(t)}
    end
  end
end
