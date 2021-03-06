#encoding: utf-8
require 'vpim/vcard'
require 'vpim/book'

class Person < ActiveRecord::Base
  has_paper_trail :on => [:destroy],
                  :meta => { person_id: :id }

  belongs_to :interaction_initiator
  has_many :interactions, class_name: "Interaction", foreign_key: "receiver_id", conditions: ["deleted_at IS NULL"]
  has_many :interactions_with_deleted, class_name: "Interaction", foreign_key: "receiver_id"
  has_many :created_interactions, class_name: "Interaction", foreign_key: "created_by_id"
  has_many :organizational_labels, dependent: :destroy, conditions: ["removed_date IS NULL"]
  has_many :labels, through: :organizational_labels
  has_many :created_organizational_labels, class_name: 'OrgnizationalLabel', foreign_key: 'added_by_id'
  has_many :group_memberships
  has_many :groups, through: :group_memberships
  has_many :charts

  has_one :sent_person
  has_many :sent_messages, class_name: "Message", foreign_key: "person_id"
  has_many :received_messages, class_name: "Message", foreign_key: "receiver_id"
  has_many :person_transfers
  has_many :new_people
  has_one :transferred_by, class_name: "PersonTransfer", foreign_key: "transferred_by_id"
  belongs_to :user, class_name: 'User', foreign_key: 'user_id'
  has_many :phone_numbers, autosave: true
  has_one :primary_phone_number, class_name: "PhoneNumber", foreign_key: "person_id", conditions: {primary: true}
  has_many :locations
  has_one :latest_location, order: "updated_at DESC", class_name: 'Location'
  has_many :interests
  has_many :education_histories
  has_many :email_addresses, autosave: true, dependent: :destroy
  has_one :primary_email_address, class_name: "EmailAddress", foreign_key: "person_id", conditions: {primary: true}
  has_one :primary_org_permission, class_name: "OrganizationalPermission", foreign_key: "person_id", conditions: {primary: true}
  has_one :primary_org, through: :primary_org_permission, source: :organization
  has_many :answer_sheets
  has_many :contact_assignments, class_name: "ContactAssignment", foreign_key: "assigned_to_id", dependent: :destroy, conditions: ["contact_assignments.person_id IS NOT NULL"]
  has_many :assigned_tos, class_name: "ContactAssignment", foreign_key: "person_id"
  has_many :assigned_contacts, through: :contact_assignments, source: :assigned_to
  has_one :current_address, class_name: "Address", foreign_key: "person_id", conditions: {address_type: 'current'}, autosave: true
  has_many :addresses, class_name: 'Address', foreign_key: :person_id, dependent: :destroy
  has_many :rejoicables, inverse_of: :person

  has_many :organization_memberships, inverse_of: :person
  has_many :organizational_permissions, conditions: {archive_date: nil, deleted_at: nil}
  has_many :organizational_permissions_including_archived, class_name: "OrganizationalPermission", foreign_key: "person_id", conditions: {deleted_at: nil}
  has_one :contact_permission, class_name: 'OrganizationalPermission'
  has_many :permissions, through: :organizational_permissions
  has_many :permissions_including_archived, through: :organizational_permissions_including_archived, source: :permission

  if Permission.table_exists? # added for travis testing
    has_many :organizations, through: :organizational_permissions, conditions: ["status = 'active' AND organizational_permissions.permission_id <> #{Permission::NO_PERMISSIONS_ID}"], uniq: true
    has_many :active_organizations, through: :organizational_permissions, source: :organization, conditions: ["status = 'active' AND organizational_permissions.permission_id <> #{Permission::NO_PERMISSIONS_ID} AND organizational_permissions.archive_date IS NULL AND organizational_permissions.deleted_at IS NULL"], uniq: true
  end

  has_many :followup_comments, :class_name => "FollowupComment", :foreign_key => "commenter_id"
  has_many :comments_on_me, :class_name => "FollowupComment", :foreign_key => "contact_id"

  has_many :received_sms, class_name: "ReceivedSms", foreign_key: "person_id"
  has_many :sms_sessions, inverse_of: :person

  has_many :group_memberships

  has_one :person_photo

  scope :who_answered, lambda {|survey_id| includes(:answer_sheets).where(AnswerSheet.table_name + '.survey_id' => survey_id)}
  validates_presence_of :first_name
  #validates_format_of :email, with: /^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i, allow_blank: true

  validate do |value|
    # validate date format
    ["birth_date","graduation_date"].each do |field_name|
      raw_date = value.send("#{field_name}_before_type_cast")
      next unless raw_date.present?
      if raw_date =~ /^([1-9]|0[1-9]|1[012])\/([1-9]|0[1-9]|[12][0-9]|3[01])\/(19|2\d)\d\d$/
        begin
          date_str = raw_date.split('/')
          self[:"#{field_name}"] = Date.parse("#{date_str[2]}-#{date_str[0]}-#{date_str[1]}")
        rescue
          errors.add(:"#{field_name}", "invalid - should be MM/DD/YYYY")
        end
      elsif raw_date =~ /^(19|2\d)\d\d\-([1-9]|0[1-9]|1[0-2])\-([1-9]|[012][0-9]|3[01])/
        begin
          self[:"#{field_name}"] = Date.parse(raw_date.split(' ').first)
        rescue
          errors.add(:"#{field_name}", "invalid - should be MM/DD/YYYY")
        end
      elsif raw_date.is_a?(Date)
        self[:"#{field_name}"] = birth_date
      else
        errors.add(:"#{field_name}", "invalid - should be MM/DD/YYYY")
      end
    end
  end

  accepts_nested_attributes_for :email_addresses, :reject_if => lambda { |a| a[:email].blank? }, allow_destroy: true
  accepts_nested_attributes_for :phone_numbers, :reject_if => lambda { |a| a[:number].blank? }, allow_destroy: true
  accepts_nested_attributes_for :addresses, :reject_if => lambda { |a| a[:address1].blank? }, allow_destroy: true
  accepts_nested_attributes_for :current_address, allow_destroy: true

  scope :find_by_person_updated_by_daterange, lambda { |date_from, date_to| {
    :conditions => ["date_attributes_updated >= ? AND date_attributes_updated <= ? ", date_from, date_to]
  }}

  scope :find_by_last_login_date_before_date_given, lambda { |after_date| {
    :select => "people.*",
    :joins => "JOIN users AS ssm ON ssm.id = people.user_id",
    :conditions => ["ssm.current_sign_in_at <= ? OR (ssm.current_sign_in_at IS NULL AND ssm.created_at <= ?)", after_date, after_date]
  }}

  scope :find_by_date_created_before_date_given, lambda { |before_date| {
    :select => "people.*",
    :joins => "LEFT JOIN organizational_permissions AS ors ON people.id = ors.person_id",
    :conditions => ["ors.permission_id = ? AND ors.created_at <= ? AND (ors.archive_date IS NULL AND ors.deleted_at IS NULL)", Permission::NO_PERMISSIONS_ID, before_date]
  }}

  scope :order_by_highest_default_permission, lambda { |order, tables_already_joined = false| {
    :select => "people.*",
    :joins => "#{'JOIN organizational_permissions ON people.id = organizational_permissions.person_id JOIN permissions ON organizational_permissions.permission_id = permissions.id' unless tables_already_joined}",
    :conditions => "permissions.i18n IN #{Permission.default_permissions_for_field_string(order.include?("asc") ? Permission::DEFAULT_PERMISSIONS : Permission::DEFAULT_PERMISSIONS.reverse)}",
    :order => "FIELD#{Permission.i18n_field_plus_default_permissions_for_field_string(order.include?("asc") ? Permission::DEFAULT_PERMISSIONS : Permission::DEFAULT_PERMISSIONS.reverse)}"
  } }

  scope :order_by_followup_status, lambda { |order| {
    :order => "ISNULL(organizational_permissions.followup_status) #{order.include?("asc") ? 'ASC' : 'DESC'}, organizational_permissions.#{order}"
  } }


  # Start of custom sorting for meta_search

  scope :sort_by_followup_status_asc,
    order("ISNULL(organizational_permissions.followup_status), organizational_permissions.followup_status ASC")

  scope :sort_by_followup_status_desc,
    order("ISNULL(organizational_permissions.followup_status), organizational_permissions.followup_status DESC")

  scope :sort_by_phone_number_asc,
    order("phone_numbers.number ASC}")

  scope :sort_by_phone_number_desc,
    order("phone_numbers.number DESC}")

  scope :sort_by_labels_asc,
    where("id <> 0")

  scope :sort_by_labels_desc,
    where("id <> 0")

  scope :sort_by_last_survey_asc,
    order("ISNULL(ass.updated_at), MAX(ass.updated_at) DESC")

  scope :sort_by_last_survey_desc,
    order("ISNULL(ass.updated_at), MAX(ass.updated_at) ASC")

  # End of custom sorting for meta_search

  scope :order_by_primary_phone_number, lambda { |order| {
    :select => "people.*, `phone_numbers`.number",
    :joins => "LEFT JOIN `phone_numbers` ON `phone_numbers`.`person_id` = `people`.`id` AND `phone_numbers`.`primary` = 1",
    :order => "ISNULL(`phone_numbers`.number), `phone_numbers`.number #{order.include?("asc") ? 'ASC' : 'DESC'}"
  } }

  scope :order_by_primary_email_address, lambda { |order| {
      :select => "people.*, `email_addresses`.email",
      :joins => "LEFT JOIN `email_addresses` ON `email_addresses`.`person_id` = `people`.`id` AND `email_addresses`.`primary` = 1",
      :order => "ISNULL(`email_addresses`.email), `email_addresses`.email #{order.include?("asc") ? 'ASC' : 'DESC'}"
  } }

  scope :order_by_permission, lambda { |order| {
      :select => "people.*",
      :joins => 'JOIN permissions ON organizational_permissions.permission_id = permissions.id',
      :conditions => "permissions.i18n IN #{Permission.default_permissions_for_field_string(Permission::DEFAULT_PERMISSIONS)}",
      :order => "FIELD#{Permission.i18n_field_plus_default_permissions_for_field_string(order.include?("asc") ? Permission::DEFAULT_PERMISSIONS : Permission::DEFAULT_PERMISSIONS.reverse)}"
  } }

  scope :find_friends_with_fb_uid, lambda { |person| { conditions: {fb_uid: Friend.followers(person)} } }

  scope :search_by_name_or_email, lambda { |keyword, org_id| {
    :select => "people.*",
    :conditions => ["(org_permissions.organization_id = #{org_id} AND (concat(first_name,' ',last_name) LIKE ? OR concat(last_name, ' ',first_name) LIKE ? OR emails.email LIKE ?))", "%#{keyword}%", "%#{keyword}%", "%#{keyword}%"],
    :joins => "LEFT JOIN email_addresses AS emails ON emails.person_id = people.id LEFT JOIN organizational_permissions AS org_permissions ON people.id = org_permissions.person_id"
  }}

  scope :email_search, lambda { |keyword, org_id| {
    :select => "people.*",
    :conditions => ["(org_permissions.organization_id = #{org_id} AND (concat(first_name,' ',last_name) LIKE ? OR concat(last_name, ' ',first_name) LIKE ? OR emails.email LIKE ?)) AND emails.email IS NOT NULL", "%#{keyword}%", "%#{keyword}%", "%#{keyword}%"],
    :joins => "LEFT JOIN email_addresses AS emails ON emails.person_id = people.id LEFT JOIN organizational_permissions AS org_permissions ON people.id = org_permissions.person_id",
    :limit => 5
  }}

  scope :phone_search, lambda { |keyword, org_id| {
    :select => "people.*",
    :conditions => ["(org_permissions.organization_id = ? AND (concat(first_name,' ',last_name) LIKE ? OR first_name LIKE ? OR last_name LIKE ? OR phone_numbers.number LIKE ?)) AND phone_numbers.number IS NOT NULL AND phone_numbers.primary = 1", org_id, "%#{keyword}%", "%#{keyword}%", "%#{keyword}%", "%#{keyword}%"],
    :joins => "LEFT JOIN phone_numbers ON phone_numbers.person_id = people.id LEFT JOIN organizational_permissions AS org_permissions ON org_permissions.person_id = people.id",
    :limit => 5
  }}

  scope :get_and_order_by_label, lambda { |order, org_id| {
    :joins => "LEFT JOIN (SELECT org_labels.person_id, org_labels.id as org_label_id, labels.name as lbl_name, labels.i18n as lbl_i18n, labels.id as lbl_id FROM organizational_labels org_labels INNER JOIN labels ON labels.id = org_labels.label_id WHERE org_labels.id IS NOT NULL AND org_labels.organization_id = '#{org_id}' AND org_labels.removed_date IS NULL ORDER BY FIELD#{Label.i18n_field_plus_default_labels_for_field_string(Label::DEFAULT_CRU_LABELS.reverse)} DESC, labels.name) new_i18n ON new_i18n.person_id = people.id",
    :group => "people.id",
    :order => "ISNULL(new_i18n.lbl_id), FIELD#{Label.custom_field_plus_default_labels_for_field_string('new_i18n.lbl_i18n',Label::DEFAULT_CRU_LABELS.reverse)} #{order.include?('desc') ? 'ASC' : 'DESC'}, new_i18n.lbl_name #{order.include?('desc') ? 'DESC' : 'ASC'}"
  }}

  scope :get_and_order_by_latest_answer_sheet_answered, lambda { |order, org_id| {
    :joins => "LEFT JOIN (SELECT ass.updated_at, ass.person_id FROM answer_sheets ass INNER JOIN surveys ms ON ms.id = ass.survey_id WHERE ms.organization_id = '#{org_id}' ORDER BY ass.updated_at DESC) ass ON ass.person_id = people.id",
    :group => "people.id",
    :order => "ISNULL(ass.updated_at), MAX(ass.updated_at) #{order.include?("asc") ? 'ASC' : 'DESC'}"
  }}

  scope :find_by_survey_updated_by_daterange, lambda { |date_from, date_to, org_id| {
    :joins => "LEFT JOIN (SELECT ass.updated_at, ass.person_id FROM answer_sheets ass INNER JOIN surveys ms ON ms.id = ass.survey_id WHERE ms.organization_id = '#{org_id}' ORDER BY ass.updated_at DESC) ass ON ass.person_id = people.id",
    :group => "people.id",
    :having => ["DATE(MAX(ass.updated_at)) >= ? AND DATE(MAX(ass.updated_at)) <= ? ", date_from, date_to]
  }}

  scope :with_label, lambda { |label, org|
    joins(:organizational_labels).where('organizational_labels.label_id' => label.id, 'organizational_labels.organization_id' => org.id, 'organizational_labels.removed_date' => nil)
  }

  scope :non_staff, -> { where(is_staff: false) }
  scope :faculty, -> { non_staff.where(faculty: true) }
  scope :students, -> { non_staff.where(faculty: false) }

  def all_organizational_permissions_for_org_id(org_id)
    OrganizationalPermission.where("person_id = ? AND organization_id = ?", id, org_id)
  end

  def ensure_single_permission_for_org_id(org_id, permission_id = nil)
    org_permissions_with_archived = all_organizational_permissions_for_org_id(org_id)
    org_permissions = organizational_permissions.where("organizational_permissions.organization_id = ?", org_id)

    if org_permissions.count == 0
      return nil
    elsif org_permissions.count == 1
      org_permission = org_permissions.first
      if org_permission.present?
        org_permissions_with_archived.where("organizational_permissions.id <> ?", org_permission.id).destroy_all
        return org_permission.try(:permission)
      else
        return nil
      end
    elsif permission_id.present? && permission = Permission.where(id: permission_id).first
      return org_permissions.first.try(:permission) if permission.nil?
    end

    if permission_id.present?
      # Clean permissions by priority
      priority = org_permissions.where("organizational_permissions.permission_id = ?", permission.id).first
      if priority.present?
        org_permission = priority
        org_permissions_with_archived.where("organizational_permissions.id <> ?", org_permission.id).destroy_all
        return org_permission.try(:permission)
      else
        return org_permissions.first.try(:permission)
      end
    else
      # Clean permissions by hierarchy
      admin = org_permissions.where("organizational_permissions.permission_id = ?", Permission::ADMIN_ID).first
      if admin.present?
        org_permission = admin
        org_permissions_with_archived.where("organizational_permissions.id <> ?", org_permission.id).destroy_all
        return org_permission.try(:permission)
      end

      user = org_permissions.where("organizational_permissions.permission_id = ?", Permission::USER_ID).first
      if user.present?
        org_permission = user
        org_permissions_with_archived.where("organizational_permissions.id <> ?", org_permission.id).destroy_all
        return org_permission.try(:permission)
      end

      contact = org_permissions.where("organizational_permissions.permission_id = ?", Permission::NO_PERMISSIONS_ID).first
      if contact.present?
        org_permission = contact
        org_permissions_with_archived.where("organizational_permissions.id <> ?", org_permission.id).destroy_all
        return org_permission.try(:permission)
      end
    end
  end


  def filtered_interactions(viewer, current_org)
    q = Array.new

    # filter organization
    if viewer.user.can?(:manage_contacts, current_org) #current_org.people.where(id: viewer.id).present?
      q << "(interactions.privacy_setting = 'organization' AND interactions.organization_id = #{current_org.id})"
    end

    # filter admins
    if viewer.admin_of_org?(current_org)
      q << "(interactions.privacy_setting = 'admins' AND interactions.organization_id = #{current_org.id})"
    end

    # filter me
    q << "(interactions.privacy_setting = 'me' AND interactions.created_by_id = #{viewer.id})"

    query = q.join(" OR ") # combine queries
    return self.interactions.joins(:organization).where(query).sorted
  end

  def labeled_in_org(label, org)
    organizational_labels.where(label_id: label.id, organization_id: org.id, removed_date: nil)
  end

  def labeled_in_org?(label, org)
    labeled_in_org(label, org).count > 0
  end

  def has_interaction_in_org?(interaction_type_ids, org)
    interactions.where(interaction_type_id: interaction_type_ids, organization_id: org.id, deleted_at: nil).count > 0
  end

  def admin_of_org?(org)
    return admin_of_org_ids.include?(org.id)
  end

  def all_feeds(current_person, current_organization, page = 1)
    limit = 5
    offset = page > 1 ? (page * limit) - limit : 0
    interaction_ids = filtered_interactions(current_person, current_organization).pluck(:id).join(',')
    interaction_ids = "0" unless interaction_ids.present?
    survey_ids = current_organization.survey_ids.join(',')
    survey_ids = "0" unless survey_ids.present?
    message_ids = received_messages_in_org(current_organization.id).pluck(:id).join(',')
    message_ids = "0" unless message_ids.present?

    counts = Person.find_by_sql("SELECT COUNT(people.id) AS COUNT FROM people LEFT JOIN interactions ON interactions.receiver_id = people.id WHERE people.id = #{id} AND interactions.id IN (#{interaction_ids}) UNION SELECT COUNT(people.id) AS COUNT FROM people LEFT JOIN answer_sheets ON answer_sheets.person_id = people.id WHERE people.id = #{id} AND answer_sheets.completed_at IS NOT NULL AND answer_sheets.survey_id IN (#{survey_ids}) UNION SELECT COUNT(people.id) AS COUNT FROM people LEFT JOIN organizational_labels ON organizational_labels.person_id = people.id WHERE organizational_labels.organization_id = #{current_organization.id} AND people.id = #{id} UNION SELECT COUNT(people.id) AS COUNT FROM people LEFT JOIN messages ON messages.receiver_id = people.id WHERE people.id = #{id} AND messages.created_at IS NOT NULL AND messages.id IN (#{message_ids})")

    total = 0;
    counts.each{|x| total += x['COUNT']}
    max_page = (total.to_f / limit.to_f).ceil
    if page > max_page
      return []
    else
      records = Person.find_by_sql("SELECT @var := 'Interaction' AS CLASS, interactions.id AS RECORD_ID, Timestamp(interactions.timestamp) AS SORT_DATE FROM people LEFT JOIN interactions ON interactions.receiver_id = people.id WHERE people.id = #{id} AND interactions.id IN (#{interaction_ids}) UNION SELECT @var := 'AnswerSheet' AS CLASS, answer_sheets.id AS RECORD_ID, answer_sheets.completed_at AS SORT_DATE FROM people LEFT JOIN answer_sheets ON answer_sheets.person_id = people.id WHERE people.id = #{id} AND Timestamp(answer_sheets.completed_at) IS NOT NULL AND answer_sheets.survey_id IN (#{survey_ids}) UNION SELECT @var := 'OrganizationalLabel' AS CLASS, organizational_labels.id AS RECORD_ID, Timestamp(organizational_labels.start_date) AS SORT_DATE FROM people LEFT JOIN organizational_labels ON organizational_labels.person_id = people.id WHERE organizational_labels.organization_id = #{current_organization.id} AND people.id = #{id} UNION SELECT @var := 'Message' AS CLASS, messages.id AS RECORD_ID, messages.created_at AS SORT_DATE FROM people LEFT JOIN messages ON messages.receiver_id = people.id WHERE people.id = #{id} AND Timestamp(messages.created_at) IS NOT NULL AND messages.id IN (#{message_ids}) ORDER BY Date(SORT_DATE) DESC, Time(SORT_DATE) DESC LIMIT #{limit} OFFSET #{offset}")
      return records.collect{|x| x['CLASS'].constantize.find(x['RECORD_ID']) }
    end
  end

  def all_feeds_last(current_person, current_organization)
    interaction_ids = filtered_interactions(current_person, current_organization).pluck(:id).join(',') || 0
    interaction_ids = "0" unless interaction_ids.present?
    survey_ids = current_organization.survey_ids.join(',')
    survey_ids = "0" unless survey_ids.present?
    message_ids = received_messages_in_org(current_organization.id).pluck(:id).join(',')
    message_ids = "0" unless message_ids.present?
    record = Person.find_by_sql("SELECT @var := 'Interaction' AS CLASS, interactions.id AS RECORD_ID, Timestamp(interactions.timestamp) AS SORT_DATE FROM people LEFT JOIN interactions ON interactions.receiver_id = people.id WHERE people.id = #{id} AND interactions.id IN (#{interaction_ids}) UNION SELECT @var := 'AnswerSheet' AS CLASS, answer_sheets.id AS RECORD_ID, Timestamp(answer_sheets.completed_at) AS SORT_DATE FROM people LEFT JOIN answer_sheets ON answer_sheets.person_id = people.id WHERE people.id = #{id} AND answer_sheets.completed_at IS NOT NULL AND answer_sheets.survey_id IN (#{survey_ids}) UNION SELECT @var := 'OrganizationalLabel' AS CLASS, organizational_labels.id AS RECORD_ID, Timestamp(organizational_labels.start_date) AS SORT_DATE FROM people LEFT JOIN organizational_labels ON organizational_labels.person_id = people.id WHERE organizational_labels.organization_id = #{current_organization.id} AND people.id = #{id} UNION SELECT @var := 'Message' AS CLASS, messages.id AS RECORD_ID, messages.created_at AS SORT_DATE FROM people LEFT JOIN messages ON messages.receiver_id = people.id WHERE people.id = #{id} AND Timestamp(messages.created_at) IS NOT NULL AND messages.id IN (#{message_ids}) ORDER BY Date(SORT_DATE) ASC, Time(SORT_DATE) ASC LIMIT 1")
    return [] unless record.present?
    return record.first['CLASS'].constantize.find(record.first['RECORD_ID'])
  end

  def messages_in_org(org_id)
    sent_messages.where("organization_id = ?", org_id).order('created_at DESC')
  end

  def received_messages_in_org(org_id)
    received_messages.where("organization_id = ?", org_id).order('created_at DESC')
  end

  def permission_for_org_id(org_id)
    organizational_permissions.where("organizational_permissions.organization_id = ?", org_id).first.permission
  end

  def contact_permission_for_org(org)
    organizational_permissions.where("organizational_permissions.organization_id = ? AND organizational_permissions.permission_id = ?", org.id, Permission::NO_PERMISSIONS_ID).first
  end

  def user_permission_for_org(org)
    organizational_permissions.where("organizational_permissions.organization_id = ? AND organizational_permissions.permission_id = ?", org.id, Permission::USER_ID).first
  end

  def permission_for_org(org)
    organizational_permissions.where("organizational_permissions.organization_id = ?", org.id).first
  end

  def is_admin_for_org?(org)
    organizational_permissions.where("organizational_permissions.organization_id = ? && organizational_permissions.permission_id = ?", org.id, Permission::ADMIN_ID).first.present?
  end

  def is_user_for_org?(org)
    organizational_permissions.where("organizational_permissions.organization_id = ? && organizational_permissions.permission_id = ?", org.id, Permission::USER_ID).first.present?
  end

  def is_admin_or_user_for_org?(org)
    organizational_permissions.where("organizational_permissions.organization_id = ? && organizational_permissions.permission_id IN (?)", org.id, [Permission::ADMIN_ID,Permission::USER_ID]).first.present?
  end

  def is_leader_for_org?(org)
    organizational_permissions.where("organizational_permissions.organization_id = ? && organizational_permissions.permission_id IN (?)", org.id, [Permission::ADMIN_ID,Permission::USER_ID]).first.present?
  end

  def leader_for_org(org)
    has_permission = organizational_permissions.where("organizational_permissions.organization_id = ? AND organizational_permissions.permission_id <> ?", org.id, Permission::NO_PERMISSIONS_ID).first
    return (has_permission.present?) ? has_permission : false
  end

  def completed_answer_sheets(organization)
    answer_sheets.where("survey_id IN (?)", Survey.where("organization_id = ? OR id = ?", organization.id, APP_CONFIG['predefined_survey']).collect(&:id)).order('updated_at DESC')
  end

  def latest_answer_sheet(organization)
  	answer_sheets.includes(:survey).where("surveys.organization_id = ?",organization.id).order("answer_sheets.updated_at DESC").first
  end

  scope :get_archived, lambda { |org_id| {
    :conditions => "(organizational_permissions.archive_date IS NOT NULL AND organizational_permissions.deleted_at IS NULL)",
    :group => "people.id",
    :having => "COUNT(*) = (SELECT COUNT(*) FROM people AS mpp JOIN organizational_permissions orss ON mpp.id = orss.person_id WHERE mpp.id = people.id AND orss.organization_id = #{org_id})"
  } }

  scope :get_from_group, lambda { |group_id| {
    :select => "people.*",
    :joins => "LEFT JOIN #{GroupMembership.table_name} AS gm ON gm.person_id = people.id",
    :conditions => ["gm.group_id = ?", group_id]
  } }

  scope :get_leaders_from_group, lambda { |group_id| {
    :select => "people.*",
    :joins => "LEFT JOIN #{GroupMembership.table_name} AS gm ON gm.person_id = people.id",
    :conditions => ["gm.group_id = ? AND gm.role = 'leader'", group_id]
  } }

  def self.archived(org_id)
    self.get_archived(org_id).collect()
  end

  def self.people_for_labels(org)
    Person.where('organizational_permissions.organization_id' => org.id).includes(:organizational_permissions)
  end

  scope :get_archived_included, lambda { {
    :group => "people.id"
  } }

  def self.archived_included
    self.get_archived_included.collect()
  end

  scope :get_archived_not_included, lambda { {
    :conditions => "(organizational_permissions.archive_date IS NULL AND organizational_permissions.deleted_at IS NULL)",
    :group => "people.id"
  } }

  def self.archived_not_included
    self.get_archived_not_included.collect()
  end

  def select_name
    "#{first_name} #{last_name} #{'-' if last_name.present? || first_name.present?} #{pretty_phone_number}"
  end

  def select_name_email
    "#{first_name} #{last_name} #{'-' if last_name.present? || first_name.present?} #{email}"
  end

  def set_as_sent
    SentPerson.find_or_create_by_person_id(id)
  end

  def self.deleted
    self.get_deleted.collect()
  end

  def unachive_contact_permission(org)
    OrganizationalPermission.where(organization_id: org.id, permission_id: Permission::NO_PERMISSIONS_ID, person_id: id).first.unarchive
  end

  def archive_contact_permission(org)
    begin
      OrganizationalPermission.where(organization_id: org.id, permission_id: Permission::NO_PERMISSIONS_ID, person_id: id).first.archive
    rescue

    end
  end

  def archive_user_permission(org)
    begin
      OrganizationalPermission.where(organization_id: org.id, permission_id: Permission::USER_ID, person_id: id).first.archive
    rescue

    end
  end

  def is_archived?(org)
    org_permission = organizational_permission_for_org(org)
    return org_permission.present? && org_permission.archive_date.present? && org_permission.deleted_at.nil?
  end

  def assigned_tos_by_org(org)
    assigned_tos.where(organization_id: org.id)
  end

  def assigned_to_people_by_org(org)
    ids = assigned_tos.where(organization_id: org.id).collect(&:assigned_to_id)
    return Person.where(id: ids)
  end

  def assigned_contacts_limit_org(org)
    assigned_id_list = ContactAssignment.where(assigned_to_id: id, organization_id: org.id)
    people = org.all_people.where(id: assigned_id_list.collect(&:person_id).uniq)
  end

  def assigned_contacts_limit_org_with_archived(org)
    assigned_id_list = ContactAssignment.where(assigned_to_id: id, organization_id: org.id)
    people = org.all_people_with_archived.where(id: assigned_id_list.collect(&:person_id).uniq)
  end

  def has_similar_person_by_name_and_email?(email)
    Person.joins(:primary_email_address).where(first_name: first_name, last_name: last_name, 'email_addresses.email' => email).where("people.id != ?", id).first
  end

  def update_date_attributes_updated
    self.date_attributes_updated = DateTime.now.to_s(:db)
    self.save
  end


  def self.search_by_name(name, organization_ids = nil, scope = nil)
    return scope.where('1 = 0') unless name.present?
    scope ||= Person

    conditions = ["LOWER(CONCAT(first_name, ' ' , last_name)) LIKE ?", "%#{name.downcase}%"]

    scope = scope.where(conditions)
    scope = scope.where('organizational_permissions.organization_id IN(?)', organization_ids).includes(:organizational_permissions) if organization_ids
    scope
  end

  def self.search_by_name_with_email_present(name, organization_ids = nil, scope = nil)
    search_by_name(name, organization_ids, scope).
      includes(:primary_email_address).
      where('email_addresses.email IS NOT NULL')
  end

  def to_s
    [first_name.to_s, last_name.to_s.strip].join(' ')
  end

  def facebook_url
    if fb_uid.present?
      "http://www.facebook.com/profile.php?id=#{fb_uid}"
    end
  end

  def user_in?(org)
    return false unless org
    OrganizationalPermission.where(person_id: id, permission_id: Permission.user_ids, :organization_id => org.id).present?
  end

  def organization_objects
    @organization_objects ||= Hash[all_organization_and_children.collect {|o| [o.id, o]}]
  end

  def all_organization_and_children
    @all_organization_and_children ||= Organization.where(:id => org_ids.keys).order('name')
  end

  def org_ids
    unless @org_ids
      unless Rails.cache.exist?(['org_ids_cache', self])
        organization_tree # make sure the tree is built
      end
      # convert org ids to integers (there has to be a better way, but i couldn't think of it)
      @org_ids = {}
      org_ids_cache.collect {|org_id, values| @org_ids[org_id.to_i] = values} if org_ids_cache.present?
    end
    @org_ids
  end

  def organization_tree
    Rails.cache.fetch(['organization_tree', self]) do
      tree = org_tree_node
      Rails.cache.write(['org_ids_cache', self], @org_ids)
      tree
    end
  end

  def org_ids_cache
    unless Rails.cache.exist?(['org_ids_cache', self])
      organization_tree # make sure the tree is built
    end
    Rails.cache.fetch(['org_ids_cache', self])
  end

  def organization_from_id(org_id)
    organization_objects[org_id.to_i]
  end

  def permissions_by_org_id(org_id)
    unless @permissions_by_org_id
      @permissions_by_org_id = Hash[OrganizationalPermission.connection.select_all("select organization_id, group_concat(permission_id) as permission_ids from organizational_permissions where person_id = #{id} and (archive_date is NULL and deleted_at is NULL) group by organization_id").collect { |row| [row['organization_id'], row['permission_ids'].to_s.split(',').map(&:to_i) ]}]
    end
    @permissions_by_org_id[org_id]
  end

  def permissions_for_org_id(org_id)
    permissions.where(id: permissions_by_org_id(org_id)).uniq
  end

  def labels_by_org_id(org_id)
    unless @labels_by_org_id
      @labels_by_org_id = Hash[OrganizationalLabel.connection.select_all("select organization_id, group_concat(label_id) as label_ids from organizational_labels where person_id = #{id} and removed_date is NULL group by organization_id").collect { |row| [row['organization_id'], row['label_ids'].split(',').map(&:to_i) ]}]
    end
    @labels_by_org_id[org_id]
  end

  def labels_for_org_id(org_id)
    labels.where(id: labels_by_org_id(org_id)).uniq
  end

  def groups_by_org_id(org_id)
    unless @groups_by_org_id
      @groups_by_org_id = Organization.find(org_id).groups.collect(&:id).uniq
    end
  end

  def groups_for_org_id(org_id)
    groups.where(id: groups_by_org_id(org_id))
  end

  def group_memberships_for_org(org)
    group_ids = org.groups.where(organization_id: org.id).collect(&:id)
    group_memberships.where(group_id: group_ids)
  end

  def organizational_permissions_for_org(org)
    organizational_permissions.where(organization_id: org.id)
  end

  def organizational_permission_for_org(org)
    organizational_permissions.where(organization_id: org.id).try(:first)
  end

  def organizational_labels_for_org(org)
    organizational_labels.where(organization_id: org.id)
  end

  def org_tree_node(o = nil, parent_permissions = [])
    orgs = {}
    @org_ids ||= {}
    (o ? o.children : active_organizations).order('name').each do |org|
      # collect permissions associated with each org
      @org_ids[org.id] ||= {}
      @org_ids[org.id]['permissions'] = (Array.wrap(@org_ids[org.id]['permissions']) + Array.wrap(permissions_by_org_id(org.id)) + Array.wrap(parent_permissions)).uniq
      orgs[org.id] = (org.show_sub_orgs? ? org_tree_node(org, @org_ids[org.id]['permissions']) : {})
    end
    orgs
  end

  def admin_of_org_ids
    @admin_of_org_ids ||= org_ids.select {|org_id, values| Array.wrap(values['permissions']).include?(Permission.admin.id)}.keys
  end

  def user_of_org_ids
    @user_of_org_ids ||= org_ids.select {|org_id, values| (Array.wrap(values['permissions']) & Permission.user_ids).present?}.keys
  end

  def admin_or_user?
    (admin_of_org_ids + user_of_org_ids).present?
  end


  def orgs_with_children
    organizations.collect {|org|
      if org.parent
        org.parent.show_sub_orgs? ? [org] + org.children : [org]
      else
        org.show_sub_orgs? ? [org] + org.children : [org]
      end
    }.flatten.uniq_by{ |o| o.id }
  end

  def phone_number
    @phone_number = phone_numbers.detect(&:primary?).try(:number)

    unless @phone_number
      if phone_numbers.present?
        @phone_number = phone_numbers.first.try(:number)
        phone_numbers.first.update_attribute(:primary, true)
      end
    end
    @phone_number.to_s
  end

  def pretty_phone_number
    primary_phone_number.try(:pretty_number)
  end

  def phone_number=(val)
    p = nil
    if val.is_a?(Hash)
      p = self.phone_number = val[:number]
    else
      if val.to_s.strip.blank?
        primary_phone_number.try(:destroy)
      else
        if new_record? || (p = phone_numbers.find_by_number(PhoneNumber.strip_us_country_code(val))).blank?
          p = primary_phone_number || phone_numbers.new
          p.number = val
        end
        p.primary = true
      end
    end
    p
  end

  def txt_to_email_phone_numbers
    all_phone_numbers = phone_numbers.order("phone_numbers.primary DESC, phone_numbers.number ASC")
    if all_phone_numbers.present?
      numbers = all_phone_numbers.collect {|phone|
        number = phone.number.to_s + I18n.t("general.sms_append_to_phone_number")
        [(phone.primary) ? "#{number} (Primary)" : number, phone.id]
      }
    else
      numbers = [[I18n.t("general.sms_no_phone_numbers"), 0]]
    end
    numbers
  end

  delegate :address1, :address1=, :city, :city=, :state, :state=, :zip, :zip=, :country, :country=, :dorm, :dorm=, :room, :room=, to: :current_or_blank_address

  def current_or_blank_address
    self.current_address ||= build_current_address
  end

  def name
    [first_name, last_name].collect(&:to_s).join(' ')
  end

  def managed_orgs
    org_permissions = organizational_permissions.where(permission_id: Permission::ADMIN_ID)
    organizations.where(id: org_permissions.collect(&:organization_id))
  end

  def managed_orgs_with_children
    org_permissions = organizational_permissions.where(permission_id: Permission::ADMIN_ID)
    organizations.where(id: org_permissions.collect(&:organization_id))
  end

  def self.find_from_facebook(data)
    person = find_existing_person_by_fb_uid(data['id'])
    person ||= find_existing_person_by_email(data['email']) if data['email'].present?
    person
  end

  def self.create_from_facebook(data, authentication, response = nil)
    new_person = Person.create(first_name: data['first_name'].try(:strip), last_name: data['last_name'].try(:strip))
    begin
      if response.nil?
        response = MiniFB.get(authentication['token'], authentication['uid'])
      else
        response = response
      end
      new_person.update_from_facebook(data, authentication, response)
    rescue MiniFB::FaceBookError => e
      Airbrake.notify(
        :error_class   => "MiniFB::FaceBookError",
        :error_message => "MiniFB::FaceBookError: #{e.message}",
        :parameters    => {data: data, authentication: authentication, response: response}
      )
    end
    new_person
  end

  def update_from_facebook(data, authentication, response = nil)
    begin
      response ||= MiniFB.get(authentication['token'], authentication['uid'])
      begin
        self.birth_date = DateTime.strptime(data['birthday'], '%m/%d/%Y') if birth_date.blank? && data['birthday'].present?
      rescue ArgumentError; end
      self.gender = response.gender unless (response.gender.nil? && !gender.blank?)
      # save!
      unless email_addresses.detect {|e| e.email == data['email']}
        begin
          email_addresses.find_or_create_by_email(data['email'].strip) if data['email'].present?
        rescue ActiveRecord::RecordNotUnique
          return self
        end
      end

      async_get_or_update_friends_and_interests(authentication)
      get_location(authentication, response)
      get_education_history(authentication, response)

    rescue MiniFB::FaceBookError => e
      Airbrake.notify(
        :error_class   => "MiniFB::FaceBookError",
        :error_message => "MiniFB::FaceBookError: #{e.message}",
        :parameters    => {data: data, authentication: authentication, response: response}
      )
    end
    self.fb_uid = authentication['uid']
    begin
      save(validate: false)
    rescue => e
      Airbrake.notify(
        :error_class   => e.class,
        :error_message => e.message,
        :parameters    => {data: data, authentication: authentication, response: response}
      )
    end
    self
  end

  def primary_organization=(org)
    if org.present? && user
      user.primary_organization_id = org.id
      user.save!
    end
    begin
      touch # touch the timestamp to reset caches
    rescue ActiveRecord::ReadOnlyRecord
    end
  end

  def primary_organization
    unless @primary_organization
      org = self.organizations.find_by_id(user.primary_organization_id) if user && user.primary_organization_id.present?
      unless org
        org = self.organizations.first

        # save this as the primary org
        self.primary_organization = org
      end
      @primary_organization = org
    end
    @primary_organization
  end

  def gender=(gender)
    if ['male','female'].include?(gender.to_s.downcase)
      self[:gender] = gender.downcase == 'male' ? '1' : '0'
    else
      self[:gender] = gender
    end
  end

  def gender
    if ['1','0'].include?(self[:gender].to_s)
      self[:gender].to_s == '1' ? 'Male' : 'Female'
    else
      self[:gender]
    end
  end

  def email
    @email = primary_email_address.try(:email)
    @email.to_s
  end

  def emails
    return email_addresses.collect{|e| e.email.downcase}
  end

  def has_email?(e)
    return false unless e.present?
    return emails.include?(e.downcase)
  end

  def email=(val)
    return if val.blank?
    e = email_addresses.detect { |email| email.email == val }
    if e
      e.primary = true
    else
      e = email_addresses.new(email: val, primary: true)
    end
    e
  end

  def email_address=(hash)
    self.email = hash['email']
  end

  def get_friends(authentication, response = nil)
    begin
      if friends.length == 0
        response ||= MiniFB.get(authentication['token'], authentication['uid'],type: "friends")
        @friends = response['data']

        @friends.each do |friend|
          Friend.new(friend['id'], friend['name'], self)
        end
        @friends.length  #return how many friend you got from facebook for testing
      end
    rescue
      return false
    end
  end

  def update_friends(authentication, response = nil)
    begin
      response ||= MiniFB.get(authentication['token'], authentication['uid'],type: "friends")
      @fb_friends = response["data"]

      @fb_friends.each do |fb_friend|
        Friend.new(fb_friend['id'], fb_friend['name'], self)
      end

      (Friend.followers(self) - @fb_friends.collect {|f| f['id'] }).each do |uid|
        Friend.unfollow(self, uid)
      end
    rescue
      return false
    end
  end

  def get_interests(authentication, response = nil)
    begin
      if response.nil?
        @interests = MiniFB.get(authentication['token'], authentication['uid'],type: "interests")
      else @interests = response
      end
      @interests["data"].each do |interest|
        interests.find_or_initialize_by_interest_id_and_person_id_and_provider(interest['id'], id.to_i, "facebook") do |i|
          i.provider = "facebook"
          i.category = interest['category']
          i.name = interest['name']
          i.interest_created_time = interest['created_time']
        end
        save
      end
      interests.count
    rescue
      return false
    end
  end

  def get_location(authentication, response = nil)
    if response.nil?
      @location = MiniFB.get(authentication['token'], authentication['uid']).location
    else @location = response.location
    end
    Location.find_or_create_by_location_id_and_name_and_person_id_and_provider(@location['id'], @location['name'], id.to_i,"facebook") unless @location.nil?
  end

  def get_education_history(authentication, response = nil)
    if response.nil?
      @education = MiniFB.get(authentication['token'], authentication['uid']).education
    else @education = response.try(:education)
    end
    unless @education.nil?
      @education.each do |education|
        education_histories.find_or_initialize_by_school_id_and_person_id_and_provider(education.school.try(:id), id.to_i, "facebook") do |e|
          e.year_id = education.year.try(:id) ? education.year.id : e.year_id
          e.year_name = education.year.try(:name) ? education.year.name : e.year_name
          e.school_type = education.try(:type) ? education.type : e.school_type
          e.school_name = education.school.try(:name) ? education.school.name : e.school_name
          unless education.try(:concentration).nil?
            0.upto(education.concentration.length-1) do |c|
              e["concentration_id#{c+1}"] = education.concentration[c].try(:id) ? education.concentration[c].id : e["concentration_id#{c+1}"]
              e["concentration_name#{c+1}"] = education.concentration[c].try(:name) ? education.concentration[c].name : e["concentration_name#{c+1}"]
            end
          end
          unless education.try(:degree).nil?
            e.degree_id = education.degree.try(:id) ? education.degree.id : e.degree_id
            e.degree_name = education.degree.try(:name) ? education.degree.name : e.degree_name
          end
          save(validate: false)
        end
      end
    end
  end

  def contact_friends(org)
    org.people.find_friends_with_fb_uid(self)
  end

  def remove_assigned_contacts(organization)
    assigned_contact_ids = contact_assignments.collect{ |r| r.person_id }
    ContactAssignment.where(person_id: assigned_contact_ids, organization_id: organization.id).destroy_all if assigned_contact_ids.count > 0
  end

  def smart_merge(other)
    if user && other.user
      user.merge(other.user)
      return self
    elsif other.user
      other.merge(self)
      return other
    else
      merge(other)
      return self
    end

  end


  def friends
    Person.where(fb_uid: friend_uids)
  end

  def friend_uids
    Friend.followers(self)
  end

  def merge(other)
    return self if other.nil? || other == self
    reload
    ::Person.transaction do
      attributes.each do |k, v|
        next if k == ::Person.primary_key
        next if v == other.attributes[k]
        self[k] = case
                  when other.attributes[k].blank? then v
                  when v.blank? then other.attributes[k]
                  else
                    other_date = other.updated_at || other.created_at
                    this_date = updated_at || created_at
                    if other_date && this_date
                      other_date > this_date ? other.attributes[k] : v
                    else
                      v
                    end
                  end
      end

      # Addresses
      addresses.each do |address|
        other_address = other.addresses.detect {|oa| oa.address_type == address.address_type}
        address.merge(other_address) if other_address
      end
      other.addresses do |address|
        other_address = addresses.detect {|oa| oa.address_type == address.address_type}
        address.update_attribute(:person_id, id) unless address.frozen? || other_address
      end
      # Phone Numbers
      phone_numbers.each do |pn|
        opn = other.phone_numbers.detect {|oa| oa.number == pn.number && oa.extension == pn.extension}
        pn.merge(opn) if opn
      end
      other.phone_numbers.each {|pn| pn.update_attribute(:person_id, id) unless pn.frozen?}

      # Locations
      other.locations.each do |location|
        if location_ids.include?(location.id)
          location.destroy
        else
          location.update_column(:person_id, id)
        end
      end

      Friend.followers(other).each do |uid|
        friend = Friend.new(uid, nil, self)
        friend.unfollow(other)
      end

      # Interests
      other.interests.each do |i|
        if interest_ids.include?(i.id)
          i.destroy
        else
          i.update_column(:person_id, id)
        end
      end

      # Edudation Histories
      other.education_histories.each do |eh|
        if education_history_ids.include?(eh.id)
          eh.destroy
        else
          eh.update_column(:person_id, id)
        end
      end

      # Followup Comments
      other.followup_comments.each do |fc|
        fc.update_column(:commenter_id, id)
      end

      # Comments on me
      other.comments_on_me.each do |fc|
        fc.update_column(:contact_id, id)
      end

      # Email Addresses
      email_addresses.each do |pn|
        opn = other.email_addresses.detect {|oa| oa.email == pn.email}
        pn.merge(opn) if opn
      end
      emails = email_addresses.collect(&:email)
      other.email_addresses.each do |pn|
        if emails.include?(pn.email)
          pn.destroy
        else
          begin
            pn.update_attribute(:person_id, id) unless pn.frozen?
          rescue ActiveRecord::RecordNotUnique
            pn.destroy
          end
        end
      end

      # Organizational Labels
      other.organizational_labels.each do |org_label|
        begin
          org_label.update_attribute(:person_id, id) unless org_label.frozen?
        rescue ActiveRecord::RecordNotUnique
          org_label.destroy
        end
      end

      # Organizational Permissions
      organizational_permissions.each do |pn|
        opn = other.organizational_permissions.detect {|oa| oa.organization_id == pn.organization_id}
        pn.merge(opn) if opn
      end

      # Clean permission for each orgs
      other.organizations.each do |org|
        other.ensure_single_permission_for_org_id(org.id)
      end

      # Merge permissions
      other.organizational_permissions.each do |org_permission|
        unless org_permission.frozen?
          org_permission.organization.add_permission_to_person(self, org_permission.permission_id, org_permission.added_by_id)
        end
      end

      # Answer Sheets
      other.answer_sheets.collect {|as| as.update_column(:person_id, id)}

      # Contact Assignments
      other.contact_assignments.collect {|as| as.update_column(:assigned_to_id, id)}

      # SMS stuff
      other.received_sms.collect {|as| as.update_column(:person_id, id)}
      other.sms_sessions.collect {|as| as.update_column(:person_id, id)}

      # Group Memberships
      other.group_memberships.collect {|gm| gm.update_column(:person_id, id)}

      MergeAudit.create!(mergeable: self, merge_looser: other)
      other.reload
      other.destroy
      begin
        save(validate: false)
      rescue ActiveRecord::ReadOnlyRecord

      end

      reload
      self

    end
  end

  def to_hash_mini
    hash = {}
    hash['id'] = self.id
    hash['name'] = self.to_s.gsub(/\n/," ")
    hash
  end

  def to_hash_micro_user(organization)
   hash = to_hash_mini
   hash['picture'] = picture unless fb_uid.nil?
   hash['num_contacts'] = contact_assignments.for_org(organization).count
   hash['fb_id'] = fb_uid.to_s unless fb_uid.nil?
   hash
  end

  def to_hash_mini_user(org_id)
    hash = to_hash_micro_user(organization_from_id(org_id))
    hash['organizational_roles'] = apiv1_orgnizational_roles
    hash
  end

  def to_hash_assign(organization = nil)
    hash = self.to_hash_mini
    assign_hash = nil
    unless organization.nil?
      assigned_to_person = ContactAssignment.where('assigned_to_id = ? AND organization_id = ?', id, organization.id)
      assigned_to_person = assigned_to_person.empty? ? [] : assigned_to_person.collect{ |a| a.person.try(:to_hash_mini) }
      person_assigned_to = ContactAssignment.where('person_id = ? AND organization_id = ?', id, organization.id)
      person_assigned_to = person_assigned_to.empty? ? [] : person_assigned_to.collect {|c| Person.find(c.assigned_to_id).try(:to_hash_mini)}
      assign_hash = {assigned_to_person: assigned_to_person, person_assigned_to: person_assigned_to}
    end
    hash['assignment'] = assign_hash unless assign_hash.nil?
    hash
  end

  def to_hash_basic(organization = nil)
    hash = self.to_hash_assign(organization)
    hash['gender'] = gender
    hash['fb_id'] = fb_uid.to_s unless fb_uid.nil?
    hash['picture'] = picture unless fb_uid.nil? and person_photo.nil?
    status = organizational_permissions.where(organization_id: organization.id).where('followup_status IS NOT NULL') unless organization.nil?
    hash['status'] = status.first.followup_status unless (status.nil? || status.empty?)
    hash['request_org_id'] = organization.id unless organization.nil?
    hash['first_contact_date'] = answer_sheets.first.created_at.utc.to_s unless answer_sheets.empty?
    hash['date_surveyed'] = answer_sheets.last.created_at.utc.to_s unless answer_sheets.empty?
    hash['organizational_roles'] = apiv1_orgnizational_roles(false)
    hash
  end

  def apiv1_orgnizational_roles(show_sub_orgs = false)
    unless @organizational_roles_hash
      roles_array = []

      organizational_permissions = self.organizational_permissions
      organizational_permissions.each do |p|
        unless p.permission_id == Permission.no_permissions.id
          permission = Permission.find_by_id(p.permission_id)
          roles_array << {
              'org_id' => p.organization_id,
              'role' => permission.apiv1_i18n,
              'name' => permission.apiv1_name,
              'primary' => primary_organization.id == p.organization_id ? 'true' : 'false'
          }
          if show_sub_orgs
            organization = Organization.find(p.organization_id)
            if organization.present? && organization.show_sub_orgs
              organization.descendant_ids.each do |child_org_id|
                roles_array << {
                    'org_id' => child_org_id,
                    'role' => permission.apiv1_i18n,
                    'name' => permission.apiv1_name,
                    'primary' => 'false'
                }
              end
            end
          end
        end
      end

      @organizational_roles_hash = roles_array.uniq
    end
    @organizational_roles_hash
  end

  def to_hash(organization = nil)
    hash = self.to_hash_basic(organization)
    hash['first_name'] = first_name.to_s.gsub(/\n/," ")
    hash['last_name'] = last_name.to_s.gsub(/\n/," ")
    hash['phone_number'] = primary_phone_number.number if primary_phone_number
    hash['email_address'] = primary_email_address.to_s if primary_email_address
    hash['birthday'] = birth_date.to_s
    #hash['interactions'] = Interaction.get_interactions_hash(id, organization.id) if organization.present?
    hash['interests'] = Interest.get_interests_hash(id)
    hash['education'] = EducationHistory.get_education_history_hash(id)
    hash['location'] = latest_location.to_hash if latest_location
    hash['locale'] = user.try(:locale) ? user.locale : ""
    hash['organization_membership'] = organization_objects.collect {|org_id, org| {org_id: org_id, primary: (primary_organization.id == org.id).to_s, name: org.name}}
    hash
  end

  def async_get_or_update_friends_and_interests(authentication)
    begin
      Resque.enqueue(Jobs::UpdateFB, self.id, authentication,'friends')
      Resque.enqueue(Jobs::UpdateFB, self.id, authentication,'interests')
    rescue;end
  end

  def picture
    if person_photo
      Rails.env.development? ? "http://local.missionhub.com/#{person_photo.image.url}" : "http://www.missionhub.com/#{person_photo.image.url}"
    elsif fb_uid.present?
      "http://graph.facebook.com/#{fb_uid}/picture"
    end
  end

  def create_user!
    reload
    if email.present? && has_a_valid_email? #!primary_email_address.nil? ? primary_email_address.valid? : false
      if user =  User.find_by_username(email)
        if user.person
          user.person.merge(self)
          return user.person
        else
          self.user = user
        end
      else
        self.user = User.create!(:username => email, :email => email, :password => SecureRandom.hex(10))
      end
      self.save(validate: false)
      return self
    else
      # Delete invalid emails
      self.email_addresses.each {|email| email.destroy unless email.valid?}
      return nil
    end
  end

  def created_by() createdBy end

  def self.new_from_params(person_params = nil)
    person_params = person_params.with_indifferent_access || {}
    person_params[:email_address] ||= {}
    person_params[:phone_number] ||= {}

    person = Person.new(person_params.except(:email_address, :phone_number))
    person.email_address = person_params[:email_address]
    person.phone_number = person_params[:phone_number]

    find_existing_person(person)
  end
  def self.find_existing_person_by_name_and_phone(opts = {})
    opts[:number] = PhoneNumber.strip_us_country_code(opts[:number]) if opts[:number].present?
    return unless opts.slice(:first_name, :last_name, :number).all? {|_, v| v.present?}

    Person.where(first_name: opts[:first_name], last_name: opts[:last_name], 'phone_numbers.number' => opts[:number]).
           includes(:phone_numbers).first
  end

  def self.find_existing_person_by_email(email)
    return unless email.present?
    (EmailAddress.find_by_email(email) ||
      User.find_by_username(email) ||
      User.find_by_email(email)).try(:person)
  end

  def self.find_existing_person_by_email_address(email_address)
    return unless email_address
    find_existing_person_by_email(email_address.email)
  end

  def self.find_existing_person_by_fb_uid(fb_uid)
    return unless fb_uid.present?
    Person.where(fb_uid: fb_uid).first
  end

  def self.find_existing_person(person)
    other_person = find_existing_person_by_fb_uid(person.fb_uid)
    other_person ||= find_existing_person_by_email_address(person.email_addresses.first)
    person.phone_numbers.each do |phone_number|
      other_person ||= find_existing_person_by_name_and_phone({first_name: person.first_name,
                                                               last_name: person.last_name,
                                                               number: phone_number.number})
    end

    if other_person
      all_phone_numbers = other_person.phone_numbers
      person.phone_numbers.each do |phone_number|
        if phone_number.number.present? && !all_phone_numbers.where(number: phone_number.number).first.present?
          all_phone_numbers.create(phone_number.attributes.except('person_id','id'))
        end
      end
      phone = other_person.phone_numbers.first
      email = other_person.email_addresses.first
      other_person.attributes = person.attributes.except('id').select {|_, v| v.present?}
    else
      email = person.email_addresses.first
      phone = person.phone_numbers.first
    end

    #[other_person || person, email, phone]
    other_person || person
  end

  def do_not_contact(organizational_permission_id)
    organizational_permission = OrganizationalPermission.find(organizational_permission_id)
    organizational_permission.followup_status = 'do_not_contact'
    ContactAssignment.where(person_id: self.id, organization_id: organizational_permission.organization_id).destroy_all
    organizational_permission.save
  end

  def friends_and_users(organization)
    Friend.followers(self) & organization.users.collect { |l| l.fb_uid.to_s }
  end

  def friends_in_orgnization(org)
    friends.includes(:organizational_permissions).where('organizational_permissions.organization_id = ?',org.id)
  end

  def assigned_organizational_labels(organization_id)
    labels.where('organizational_labels.organization_id' => organization_id, 'organizational_labels.removed_date' => nil)
  end

  def assigned_organizational_permissions(organization_id)
    permissions = get_organizational_permissions(organization_id)

    # if in current org/sub org has no permission, get the permission to the parent org
    if !permissions.present? && get_org = Organization.find_by_id(organization_id)
      if get_org.ancestors.present?
        if get_org.ancestors.count > 1 && admin_of_org?(get_org.ancestors.last)
          # get permission from the parent of the current organization
          permissions = get_organizational_permissions(get_org.parent.id)
        end

        # if in parent org has no permission, get the permission to the root org
        unless permissions.present?
          # get permission from the root of the current organization
          permissions = get_organizational_permissions(get_org.ancestors.first.id)
        end
      end
    end

    return permissions
  end

  def get_organizational_permissions(organization_id)
    permissions.where('organizational_permissions.organization_id' => organization_id, 'organizational_permissions.archive_date' => nil, 'organizational_permissions.deleted_at' => nil)
  end

  def assigned_organizational_permissions_including_archived(organization_id)
    permissions.where('organizational_permissions.organization_id = ? AND organizational_permissions.archive_date IS NOT NULL AND organizational_permissions.deleted_at IS NULL', organization_id)
  end

  def is_permission_archived?(org_id, permission_id)
    return false if organizational_permissions_including_archived.where(organization_id: org_id, permission_id: permission_id, deleted_at: nil).first.archive_date.blank?
    true
  end

  def is_sent?
    sent_person != nil
  end

  def answer_sheet_for_survey(survey_id)
    answer_sheets.where(survey_id: survey_id).first ||
    answer_sheets.create!(survey_id: survey_id)
  end

  def self.vcard(ids)
    ids = Array.wrap(ids)
    book = Vpim::Book.new
    Person.includes(:current_address, :primary_phone_number, :primary_email_address).find(ids).each do |person|
      book << person.vcard
    end
    book
  end

  def vcard

    card = Vpim::Vcard::Maker.make2 do |maker|
      maker.add_name do |name|
        name.prefix = ''
        name.given = first_name.to_s
        name.family = last_name.to_s
      end

      if current_address
        maker.add_addr do |addr|
          addr.preferred = true
          addr.location = 'home'
          addr.street =  "#{current_address.address1} #{current_address.address2}" if current_address.address1.present? || current_address.address2.present?
          addr.locality = current_address.city if current_address.city.present?
          addr.postalcode = current_address.zip if current_address.zip.present?
          addr.region = current_address.state if current_address.state.present?
          addr.country = current_address.country if current_address.country.present?
        end
      end

      maker.birthday = birth_date if birth_date
      maker.add_tel(phone_number) if phone_number != ''
      if email != ''
        maker.add_email(email) do |email|
          email.preferred = true
          email.location = 'home'
        end
      end
    end

  end

  def has_a_valid_email?
    return email.match(/^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i)
  end

  def all_organizational_roles
    self.organizational_permissions + self.organizational_labels
  end

  def organizational_roles_for_org_id(org_id)
    self.organizational_permissions.where(organization_id: org_id) + self.organizational_labels.where(organization_id: org_id)
  end

  def roles_for_org_id(org_id)
    self.permissions_for_org_id(org_id) + self.labels_for_org_id(org_id)
  end

  def queue_for_transfer(org_id, added_by_person_id = nil)
    interaction = Interaction.new(
      interaction_type_id: InteractionType.graduating_on_mission.try(:id),
      receiver_id: id,
      created_by_id: added_by_person_id,
      organization_id: org_id,
      privacy_setting: Interaction::DEFAULT_PRIVACY
    )
    if interaction.save
      interaction.interaction_initiators.find_or_create_by_person_id(added_by_person_id)
      return interaction
    end
  end

  NATIONALITIES = ["Chinese", "South Asian (India, Nepal, Sri Lanka)", "TIP/Muslim", "American", "All Other Nations"]
  LANGUAGES = [["босански (Bosnian)", "bs"], ["官话 (Chinese) ", "zh"], ["English (English)", "en"], ["Español (Spanish)", "es"], ["Français (French)", "fr"], ["Deutsch (German)", "de"], ["Pусский (Russian)", "ru"], ["српски (Serbian)", "sr"]]

  def set_followup_status(organization, status)
    permission = permission_for_org(organization)
    if permission.present?
      permission.followup_status = status
      permission.save
    end
  end

end
