class SessionsController < Devise::SessionsController
  before_filter :prepare_for_mobile
  skip_before_filter :check_url
  layout :pick_layout
  
  def new
    @survey = Survey.find(cookies[:survey_id]) unless cookies[:survey_id].nil?
    @title = @survey.terminology
    if @survey
      if @survey.login_option == 2 || @survey.login_option == 3
        redirect_to "/s/#{cookies[:survey_id]}?nologin=true"
      end
    end
  end
  
  def destroy
    if session[:fb_token]
      split_token = session[:fb_token].split("|")
      fb_api_key = split_token[0]
      fb_session_key = split_token[1]
      session[:fb_token] = nil
    end
    super
  end
  
  protected
  
  def after_sign_out_path_for(resource_or_scope)
    params[:next] ? params[:next] : root_url
  end
  
  def pick_layout
    mhub? ? 'mhub' : 'login'
  end
end
