require 'uri'

class TopContainersController < ApplicationController

  set_access_control  "view_repository" => [:show, :typeahead, :bulk_operations_browse, :print_labels],
                      "update_container_record" => [:new, :create, :edit, :update],
                      "manage_container_record" => [:index, :delete, :batch_delete, :bulk_operations, :bulk_operation_search, :bulk_operation_update, :update_barcodes]


  def index
  end


  def new
    @top_container = JSONModel(:top_container).new._always_valid!

    render_aspace_partial :partial => "top_containers/new" if inline?
  end


  def create
    handle_crud(:instance => :top_container,
                :model => JSONModel(:top_container),
                :on_invalid => ->(){
                  return render_aspace_partial :partial => "top_containers/new" if inline?
                  return render :action => :new
                },
                :on_valid => ->(id){
                  if inline?
                    @top_container.refetch
                    render :json => @top_container.to_hash if inline?
                  else
                    flash[:success] = I18n.t("top_container._frontend.messages.created")
                    redirect_to :controller => :top_containers, :action => :show, :id => id
                  end
                })
  end


  def show
    @top_container = JSONModel(:top_container).find(params[:id], find_opts)
  end


  def edit
    @top_container = JSONModel(:top_container).find(params[:id], find_opts)
  end


  def update
    handle_crud(:instance => :top_container,
                :model => JSONModel(:top_container),
                :obj => JSONModel(:top_container).find(params[:id], find_opts),
                :on_invalid => ->(){
                  return render action: "edit"
                },
                :on_valid => ->(id){
                  flash[:success] = I18n.t("top_container._frontend.messages.updated")
                  redirect_to :controller => :top_containers, :action => :show, :id => id
                })
  end


  def delete
    top_container = JSONModel(:top_container).find(params[:id])
    top_container.delete

    redirect_to(:controller => :top_containers, :action => :index, :deleted_uri => top_container.uri)
  end

  def batch_delete
    response = JSONModel::HTTP.post_form("/batch_delete",
                                         {
                                "record_uris[]" => Array(params[:record_uris])
                                         })

    if response.code === "200"
      flash[:success] = I18n.t("top_container.batch_delete.success")
      deleted_uri_param = params[:record_uris].map{|uri| "deleted_uri[]=#{uri}"}.join("&")
      redirect_to "#{request.referrer}?#{deleted_uri_param}"
    else
      flash[:error] = "#{I18n.t("top_container.batch_delete.error")}<br/> #{ASUtils.json_parse(response.body)["error"]["failures"].map{|err| "#{err["response"]} [#{err["uri"]}]"}.join("<br/>")}".html_safe
      redirect_to request.referrer
    end
  end


  def typeahead
    search_params = params_for_backend_search

    search_params = search_params.merge(search_filter_for(params[:uri]))
    search_params = search_params.merge("sort" => "typeahead_sort_key_u_sort asc")

    render :json => Search.all(session[:repo_id], search_params)
  end


  class MissingFilterException < Exception; end


  def bulk_operation_search
    begin
      results = perform_search
    rescue MissingFilterException
      return render :text => I18n.t("top_container._frontend.messages.filter_required"), :status => 500
    end

    render_aspace_partial :partial => "top_containers/bulk_operations/results", :locals => {:results => results}
  end


  def bulk_operations_browse
    begin
      results = perform_search if params.has_key?("q")
    rescue MissingFilterException
      flash[:error] = I18n.t("top_container._frontend.messages.filter_required")
    end

    render_aspace_partial :partial => "top_containers/bulk_operations/browse", :locals => {:results => results}
  end


  def bulk_operation_update
    post_params = {'ids[]' => params['update_uris'].map {|uri| JSONModel(:top_container).id_for(uri)}}
    post_uri = "/repositories/#{session[:repo_id]}/top_containers/batch/"

    if params['ils_holding_id']
      post_params['ils_holding_id'] = params['ils_holding_id']
      post_uri += 'ils_holding_id'
    elsif params['container_profile_uri']
      post_params['container_profile_uri'] = params['container_profile'] ? params['container_profile']['ref'] : ""
      post_uri += 'container_profile'
    elsif params['location_uri']
      post_params['location_uri'] = params['location'] ? params['location']['ref'] : ""
      post_uri += 'location'
    else
      render :text => "You must provide a field to update.", :status => 500
    end
      
    response = JSONModel::HTTP::post_form(post_uri, post_params)
    result = ASUtils.json_parse(response.body)

    if result.has_key?('records_updated')
      render_aspace_partial :partial => "top_containers/bulk_operations/bulk_action_success", :locals => {:result => result}
    else
      render :text => "There seems to have been a problem with the update: #{result['error']}", :status => 500
    end
  end


  def update_barcodes
    update_uris = params[:update_uris]
    barcode_data = {}
    update_uris.map{|uri| barcode_data[uri] = params[uri].blank? ? nil : params[uri]}

    post_uri = "#{JSONModel::HTTP.backend_url}/repositories/#{session[:repo_id]}/top_containers/bulk/barcodes"

    response = JSONModel::HTTP::post_json(URI(post_uri), barcode_data.to_json)
    result = ASUtils.json_parse(response.body)

    if response.code =~ /^4/
      return render_aspace_partial :partial => 'top_containers/bulk_operations/error_messages', :locals => {:exceptions => result, :jsonmodel => "top_container"}, :status => 500
    end

    render_aspace_partial :partial => "top_containers/bulk_operations/bulk_action_success", :locals => {:result => result}
  end


  def print_labels
    post_uri = "/repositories/#{session[:repo_id]}/top_containers/bulk/labels"
    response = JSONModel::HTTP.post_form(URI(post_uri), {"record_uris[]" => Array(params[:record_uris])})
    results = ASUtils.json_parse(response.body)

    if response.code =~ /^4/
      return render_aspace_partial :partial => 'top_containers/bulk_operations/error_messages', :locals => {:exceptions => results, :jsonmodel => "top_container"}, :status => 500
    end

    render_aspace_partial :partial => "top_containers/bulk_operations/bulk_action_labels", :locals => {:labels => results}
  end


  private

  helper_method :can_edit_search_result?
  def can_edit_search_result?(record)
    return user_can?('update_container_record') if record['primary_type'] === "top_container"
    SearchHelper.can_edit_search_result?(record)
  end


  include ApplicationHelper

  helper_method :barcode_length_range
  def barcode_length_range
    check = BarcodeCheck.new(current_repo[:repo_code])
    check.min == check.max ? check.min.to_s : "#{check.min}-#{check.max}"
  end


  def search_filter_for(uri)
    return {} if uri.blank?

    return {
      "filter_term[]" => [{"collection_uri_u_sstr" => uri}.to_json]
    }
  end


  def perform_search
    unless params[:indicator].blank?
      unless params[:q].blank?
        params[:q] = "#{params[:q]} AND "
      end
      
      #convert the range into a set of indicators since indicators are defined as strings and we need exact matches
      if params[:indicator].include? "TO"
        range = params[:indicator].split
          .find_all{|e| e[/\d+/]}
          .each{|e| e.gsub!(/\[|\]/,'').to_i}
          
        indicators = (range[0]..range[range.length-1]).step(1)
      # otherwise just split the list up
      else
        indicators = params[:indicator].split
      end
      
      # then concatenate with the correct prefix and OR the search
      indicator_string = indicators.each { |e| e.prepend('indicator_u_sstr:') }.join(" OR ")
      
      params[:q] << indicator_string
    end

    search_params = params_for_backend_search.merge({
                                                      'type[]' => ['top_container']
                                                    })

    filters = []

    filters.push({'collection_uri_u_sstr' => params['collection_resource']['ref']}.to_json) if params['collection_resource']
    filters.push({'collection_uri_u_sstr' => params['collection_accession']['ref']}.to_json) if params['collection_accession']

    filters.push({'container_profile_uri_u_sstr' => params['container_profile']['ref']}.to_json) if params['container_profile']
    filters.push({'location_uri_u_sstr' => params['location']['ref']}.to_json) if params['location']
    unless params['exported'].blank?
      filters.push({'exported_u_sbool' => (params['exported'] == "yes" ? true : false)}.to_json)
    end
    unless params['empty'].blank?
      filters.push({'empty_u_sbool' => (params['empty'] == "yes" ? true : false)}.to_json)
    end

    if filters.empty? && params['q'].blank?
      raise MissingFilterException.new
    end

    unless filters.empty?
      search_params = search_params.merge({
                                            "filter_term[]" => filters
                                          })
    end

    container_search_url = "#{JSONModel(:top_container).uri_for("")}/search"
    JSONModel::HTTP::get_json(container_search_url, search_params)
  end

end

