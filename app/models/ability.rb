class Ability
  include CanCan::Ability

  def initialize(user)
    roles = Role.default.all
    leader_role = roles.detect {|r| r.i18n == 'leader'}
    admin_role = roles.detect {|r| r.i18n == 'admin'}
    involved_role = roles.detect {|r| r.i18n == 'involved'}
    user ||= User.new # guest user (not logged in)
    if user && user.person
      # admin_of_org_ids = user.person.organizations.where('organizational_roles.role_id' => admin_role.id).collect {|org| org.show_sub_orgs? ? org.self_and_children_ids : org.id}.flatten
      admin_of_org_ids = user.person.organizations.where('organizational_roles.role_id' => admin_role.id).collect {|org| org.subtree_ids}.flatten
      leader_of_org_ids = user.person.organizations.where('organizational_roles.role_id' => Role.leader_ids).collect {|org| org.show_sub_orgs? ? org.self_and_children_ids : org.id}.flatten
      
      # can :manage, Organization, id: user.person.organizational_roles.where(role_id: admin_role.id).collect(&:organization_id)
      can :manage, Organization, id: admin_of_org_ids
      can :lead, Organization, id: leader_of_org_ids
      
      can :manage_contacts, Organization, id: leader_of_org_ids

      can :manage_roles, Organization, id: admin_of_org_ids
      
      # can only manage keywords from orgs you're an admin of
      # can :manage, SmsKeyword, organization_id: user.person.organizational_roles.where(role_id: admin_role.id).collect(&:organization_id)
      can :manage, SmsKeyword, organization_id: admin_of_org_ids
      
      # Gotta be an admin somewhere to see keyword options
      unless user.person.organizational_roles.where(role_id: admin_role.id).present?
        cannot :manage, SmsKeyword
      end
      
      # involved members can see other people's info
      can :read, Person, organizational_roles: {organization_id: user.person.organizational_roles.where(role_id: [admin_role.id, leader_role.id, involved_role.id]).value_of(:organization_id)}
      can :read, PersonPresenter, organizational_roles: {organization_id: user.person.organizational_roles.where(role_id: [admin_role.id, leader_role.id, involved_role.id]).value_of(:organization_id)}
      
      # leaders and admins can edit other ppl's info
      if user.person.organizational_roles.where(role_id: [admin_role.id, leader_role.id]).present?
        can :create, SmsMailer
        can :create, Person
        can :create, PersonPresenter
      end
      
      can :manage, Person, organizational_roles: {organization_id: leader_of_org_ids}
      can :manage, Person, id: user.person.try(:id)
      can :manage, PersonPresenter, organizational_roles: {organization_id: leader_of_org_ids}
      can :manage, PersonPresenter, id: user.person.try(:id)
      
      can :manage, Group, organization_id: leader_of_org_ids
      can :manage, GroupPresenter, organization_id: leader_of_org_ids
      
      can :all, :all if user.developer?
      
    end
    #
    # The first argument to `can` is the action you are giving the user permission to do.
    # If you pass :manage it will apply to every action. Other common actions here are
    # :read, :create, :update and :destroy.
    #
    # The second argument is the resource the user can perform the action on. If you pass
    # :all it will apply to every resource. Otherwise pass a Ruby class of the resource.
    #
    # The third argument is an optional hash of conditions to further filter the objects.
    # For example, here the user can only update published articles.
    #
    #   can :update, Article, published: true
    #
    # See the wiki for details: https://github.com/ryanb/cancan/wiki/Defining-Abilities
  end
end
