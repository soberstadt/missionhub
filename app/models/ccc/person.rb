module Ccc
  module Person
    extend ActiveSupport::Concern
    
    included do
      has_many :ministry_newaddresses, :class_name => 'Ccc::MinistryNewaddress', :foreign_key => :fk_PersonID, :dependent => :destroy
			has_many :crs_registrations, :class_name => 'Ccc::CrsRegistration', :dependent => :destroy

      has_one :crs2_profiles, :class_name => 'Ccc::Crs2Profile', :dependent => :destroy
      has_one :mpd_users, :class_name => 'Ccc::MpdUser', :dependent => :destroy
      has_many :pr_reviewers, :class_name => 'Ccc::PrReviewer', :dependent => :destroy
      has_many :pr_reviews, :class_name => 'Ccc::PrReview' # dependant? subject_id, initiator_id
      has_many :pr_admins, :class_name => 'Ccc::PrAdmin', :dependent => :destroy
      has_many :pr_summary_forms, :class_name => 'Ccc::PrSummaryForm', :dependent => :destroy
      has_many :pr_reminders, :class_name => 'Ccc::PrReminders', :dependent => :destroy
      has_many :pr_personal_forms, :class_name => 'Ccc::PrPersonalForm', :dependent => :destroy
      has_one :pr_users, :class_name => 'Ccc::PrUser', :dependent => :destroy

			has_many :sp_applications, :class_name => 'Ccc::SpApplication', :dependent => :destroy
			has_many :sp_projects, :class_name => 'Ccc::SpProject'
      has_one :sp_users, :class_name => 'Ccc::SpUser'  #created by and ssm/person?
      has_many :sp_staff, :class_name => 'Ccc::SpStaff', :dependent => :destroy
			has_many :sp_application_moves, :class_name => 'Ccc::SpApplicationMove'
			has_many :sp_applies, :class_name => 'Ccc::SpApply', :dependent => :destroy
			has_many :ministry_staff, :class_name => 'Ccc::MinistryStaff', :dependent => :destroy
			has_many :hr_si_applications, :class_name => 'Ccc::HrSiApplication', :dependent => :destroy
			has_one :si_users, :class_name => 'Ccc::SiUser' #created by and ssm?
			has_many :sitrack_mpd, :class_name => 'Ccc::SitrackMpd', :dependent => :destroy
			has_many :sitrack_tracking, :class_name => 'Ccc::SitrackTracking', :dependent => :destroy
			has_many :sn_campus_involvements, :class_name => 'Ccc::SnCampusInvolvement' # don't destroy if added_by_id
			has_many :sn_custom_values, :class_name => 'Ccc::SnCustomValue', :dependent => :destroy
			has_many :sp_group_involvements, :class_name => 'Ccc::SnGroupInvolvement', :dependent => :destroy
			has_many :sn_ministry_involvements, :class_name => 'Ccc::SnMinistryInvolvement', :dependent => :destroy
			has_many :sp_user_memberships, :class_name => 'Ccc::SnUserMembership', :dependent => :destroy
			has_many :sn_training_answers, :class_name => 'Ccc::SnTrainingAnswer', :dependent => :destroy
			has_many :sn_imports, :class_name => 'Ccc::SnImport', :dependent => :destroy
      has_many :sn_timetables, :class_name => 'Ccc::SnTimetable', :dependent => :destroy
			has_many :rideshare_rides, :class_name => 'Ccc::RideshareRides', :foreign_key => :person_id, :dependent => :destroy
      has_many :profile_pictures, :class_name => 'Ccc::ProfilePicture', :dependent => :destroy
      has_many :ministry_missional_team_members, :class_name => 'Ccc::MinistryMissionalTeamMember', :dependent => :destroy
      has_many :organization_memberships, :class_name => 'Ccc::OrganizationMembership', :dependent => :destroy
    end
    
    module InstanceMethods
      def merge(other)
        ::Person.transaction do
          attributes.each do |k, v|
            next if k == ::Person.primary_key
            next if v == other.attributes[k]
            self[k] = case
                      when other.attributes[k].blank? then v
                      when v.blank? then other.attributes[k]
                      else
                        other.dateChanged > dateChanged ? other.attributes[k] : v
                      end
          end

          # Addresses
          ministry_newaddresses.each do |address|
            other_address = other.ministry_newaddresses.detect {|oa| oa.addressType == address.addressType}
            address.merge(other_address) if other_address
          end
          other.ministry_newaddresses.each {|ma| ma.update_attribute(:fk_PersonID, personID) unless ma.frozen?}
	        
 					# CRS
					other.crs_registrations.each { |ua| ua.update_attribute(:fk_PersonID, personID) }

					if other.crs2_profile and crs2_profile
	  				crs2_profile.merge(other.crs2_profile)
					elsif other.crs2_profile
						other.crs2_profile.ministry_person_id = personID
					end

					# MPD
					if other.mpd_user and mpd_user
	  				mpd_user.merge(other.mpd_user)
					elsif other.mpd_user
						other.mpd_user.user_id = fk_ssmUserID
					end

					# Panorama
					other.pr_reviewers.each { |ua| ua.update_attribute(:person_id, personID) }

					PrReview.where(["subject_id = ? or initiator_id = ?", other.id, other.id]).each do |ua|
						ua.update_attribute(:subject_id, personID) if ua.subject_id == other.id
						ua.update_attribute(:initiator_id, personID) if ua.initiator_id == other.id
					end

					other.pr_admins.each { |ua| ua.update_attribute(:person_id, personID) }
					other.pr_summary_forms.each { |ua| ua.update_attribute(:person_id, personID) }
					other.pr_reminders.each { |ua| ua.update_attribute(:person_id, personID) }
					other.pr_personal_forms.each { |ua| ua.update_attribute(:person_id, personID) }

					if other.pr_user and pr_user
						other.pr_user.destroy				
					elsif other.pr_user
						other.pr_user.ssm_id = fk_ssmUserID
					end
					# end Panorama
					
					# Summer Project Tool
					other.sp_applications.each { |ua| ua.update_attribute(:person_id, personID) }

					SpProject.where(["pd_id = ? or apd_id = ? or opd_id = ? or coordinator_id = ?", other.id, other.id, other.id, other.id]).each do |ua|
						ua.update_attribute(:pd_id, personID) if ua.pd_id == other.id
						ua.update_attribute(:apd_id, personID) if ua.apd_id == other.id
						ua.update_attribute(:opd_id, personID) if ua.opd_id == other.id
						ua.update_attribute(:coordinator_id, personID) if ua.coordinator_id == other.id
					end
					
					if other.sp_user and sp_user
						sp_user.merge(other.sp_user)
					elsif other.sp_user
						SpUser.where(["person_id = ? or ssm_id = ? or created_by_id = ?", other.id, other.fk_ssmUserId, other.fk_ssmUserId]).each do |ua|
							ua.update_attribute(:person_mid, personID) if ua.person_id == other.id
							ua.update_attribute(:ssm_id, fk_ssmUserId) if ua.ssm_id == other.fk_ssmUserID
							ua.update_attribute(:created_by_id, fk_ssmUserId) if ua.created_by_id == other.fk_ssmUserID
						end
					end

					other.sp_staff.each { |ua| ua.update_attribute(:person_id, personID) }
					other.sp_application_moves.each { |ua| ua.update_attribute(:moved_by_person_id, personID) }
					other.sp_applies.each { |ua| ua.update_attribute(:applicant_id, personID) }
					# end Summer Project Tool

					other.ministry_staff.each { |ua| ua.update_attribute(:person_id, personID) }

					other.hr_si_applications.each do |ua|
						ua.update_attribute(:fk_personID, personID)
						ua.update_attribute(:fk_ssmUserID, fk_ssmUserID)
					end

					if other.si_user and si_user
						other.si_user.destroy				
					elsif other.si_user
						SiUser.where(["ssm_id = ? or created_by_id = ?", other.fk_ssmUserID, other.fk_ssmUserID]).each do |ua|
							ua.update_attribute(:ssm_id, personID) if ua.ssm_id == other.fk_ssmUserID
							ua.update_attribute(:created_by_id, personID) if ua.created_by_id == other.fk_ssmUserID
						end
					end

					other.si_applies.each { |ua| ua.update_attribute(:applicant_id, personID) }
					other.sitrack_mpd.each { |ua| ua.update_attribute(:person_id, personID) }
					other.sitrack_tracking.each { |ua| ua.update_attribute(:person_id, personID) }

					SnCampusInvolvement.where(["person_id = ? or added_by_id = ?", other.id, other.id]).each do |ua|
						ua.update_attribute(:person_id, personID) if ua.person_id == other.id
						ua.update_attribute(:added_by_id, personID) if ua.added_by_id == other.id
					end

					# SN
					other.sn_custom_values.each { |ua| ua.update_attribute(:person_id, personID) }
					other.sn_group_involvements.each { |ua| ua.update_attribute(:person_id, personID) }
					other.sn_ministry_involvments.each { |ua| ua.update_attribute(:person_id, personID) }
					other.sn_user_memberships.each { |ua| ua.update_attribute(:user_id, personID) }
					other.sn_training_answers.each { |ua| ua.update_attribute(:person_id, personID) }
					other.sn_imports.each { |ua| ua.update_attribute(:person_id, personID) }
					other.sn_timetables.each { |ua| ua.update_attribute(:person_id, personID) }

					other.profile_pictures.each { |ua| ua.update_attribute(:person_id, personID) }
					other.ministry_missional_team_members.each { |ua| ua.update_attribute(:person_id, personID) }
					other.rideshare_rides.each {|ua| ua.update_attribute(:person_id, personID) }

 
          MergeAudit.create!(:mergeable => self, :merge_looser => other)
          other.destroy
          save(:validate => false)
				end
      end
		end
	end
end
