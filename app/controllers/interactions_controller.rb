class InteractionsController < ApplicationController
  def show_profile
    @person = current_organization.people.where(id: params[:id]).try(:first)
    redirect_to contacts_path unless @person.present?
    @interaction = Interaction.new
    @completed_answer_sheets = @person.completed_answer_sheets(current_organization).where("completed_at IS NOT NULL").order('completed_at DESC')
    if can? :manage, @person
      @interactions = @person.interactions.recent
    end
  end
  
  def change_followup_status
    @person = current_organization.people.where(id: params[:person_id]).try(:first)
    return false unless @person.present?
    @contact_role = @person.contact_role_for_org(current_organization)
    return false unless @contact_role.present?
    
    @contact_role.update_attribute(:followup_status, params[:status])
  end
  
  def reset_edit_form
    @person = current_organization.people.where(id: params[:person_id]).try(:first)
  end
  
  def create
    @interaction = Interaction.new(params[:interaction])
    @interaction.created_by_id = current_person.id
    @interaction.organization_id = current_organization.id
    if @interaction.save
      params[:initiator_id].each do |person_id|
        InteractionInitiator.create(person_id: person_id, interaction_id: @interaction.id)
      end
    end
    show_profile
  end
end