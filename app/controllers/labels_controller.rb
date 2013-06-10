class LabelsController < ApplicationController
  before_filter :ensure_current_org
  before_filter :authorize
  before_filter :set_label, :only => [:new, :edit, :update, :destroy]
 
  def index
    @organizational_labels = current_organization.non_default_labels
    @system_labels = current_organization.default_labels
  end
  
  def new
  end
  
  def edit
  end

  def create
    Label.transaction do
      @label = Label.new(params[:label])
      @label.organization_id = current_organization.id
      if @label.save
        redirect_to labels_path
      else
        render :new
      end
    end
  end
  
  def create_now
    @status = false
    if params[:name].present?
      if Label.where("LOWER(name) = ? AND organization_id IN (?)", params[:name].downcase, [current_organization.id,0]).present?
        @msg_alert = t('contacts.index.add_label_exists')
      else
        @new_label = Label.create!(name: params[:name], organization_id: current_organization.id) if params[:name].present?
        if @new_label.present?
          @status = true
          @msg_alert = t('contacts.index.add_label_success')
        else
          @msg_alert = t('contacts.index.add_label_failed')
        end
      end
    else
      @msg_alert = t('contacts.index.add_label_empty')
    end
  end

  def update
    if @label.update_attributes(params[:label])
      redirect_to labels_path
    else 
      render :edit
    end
  end

  def destroy
    @label.destroy
    redirect_to labels_path
  end

 protected
  def authorize
    authorize! :manage_labels, current_organization
  end

  def set_label
    @label = case action_name 
    when 'new' then Label.new
    else Label.find(params[:id]) 
    end 
  end
end