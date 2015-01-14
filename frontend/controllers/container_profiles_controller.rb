class ContainerProfilesController < ApplicationController

  set_access_control  "manage_container_profile_record" => [:new, :index, :edit, :create, :update, :show, :delete]


  def new
    @container_profile = JSONModel(:container_profile).new._always_valid!

    render_aspace_partial :partial => "container_profiles/new" if inline?
  end


  def index
    @search_data = Search.for_type(session[:repo_id], "container_profile", params_for_backend_search)
  end


  def show
    @container_profile = JSONModel(:container_profile).find(params[:id])
  end


  def edit
    @container_profile = JSONModel(:container_profile).find(params[:id])
  end


  def create
    handle_crud(:instance => :container_profile,
                :model => JSONModel(:container_profile),
                :on_invalid => ->(){
                  return render_aspace_partial :partial => "container_profiles/new" if inline?
                  return render :action => :new
                },
                :on_valid => ->(id){
                  if inline?
                    @container_profile.refetch
                    render :json => @container_profile.to_hash if inline?
                  else
                    flash[:success] = I18n.t("container_profile._frontend.messages.created")
                    redirect_to(:controller => :container_profiles, :action => :show, :id => id)
                  end
                })
  end


  def update

    handle_crud(:instance => :container_profile,
                :model => JSONModel(:container_profile),
                :obj => JSONModel(:container_profile).find(params[:id]),
                :replace => true,
                :on_invalid => ->(){
                  return render :action => :edit
                },
                :on_valid => ->(id){
                  redirect_to(:controller => :container_profiles, :action => :show, :id => id)
                })
  end


  def delete
    container_profile = JSONModel(:container_profile).find(params[:id])
    container_profile.delete

    redirect_to(:controller => :container_profiles, :action => :index, :deleted_uri => container_profile.uri)
  end

end
