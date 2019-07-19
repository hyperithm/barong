
#frozen_string_literal: true

require 'csv'

# REMEMBER, FIRST LINE SHOULD BE HEADERS OF THE FILE
#
# To execute script with given csv file
# rake users:import -- --csv=path/to/file

namespace 'users' do
  desc 'users from csv file'
  task :import => :environment do
    ### Parse options
    options = {}

    o = OptionParser.new

    o.banner = 'Usage: rake users:import -- -csv ~/Downloads/import_sheet.csv'
    o.on('--csv PATH', '--f pATH') { |path| options[:path] = path.to_s }

    args = o.order!(ARGV) {} # protect from wrong params
    o.parse!(args)

    errors_users_file = File.open("errors_users_file.txt", "w")
    csv_table = File.read(options[:path])
    count = 0
    CSV.parse(csv_table, :headers => true).map do |row|
      composed_uid = "ID" + (1000000000 + row['AccountId'].to_i).to_s

      User.new(
        uid: composed_uid,
        email: row['Email'],
        level: 0,
        state: 'pending',
        role: 'member',
        password: SecureRandom.hex(7) # enough to be uniq for each user and hard to brute force
      ).save!(:validate => false) # skip password Big letter, symbol and other requirements validation

      user = User.find_by_email!(row['Email'])
      case row['VerificationLevel']
      when '0'
        user.update!(state: 'active')
      when '1'
        user.after_confirmation
        level = 1
      when '2'
        user.after_confirmation
        user.add_level_label(:phone)
        user.add_level_label(:profile)
        level = 3
      when '3'
        user.after_confirmation
        user.add_level_label(:phone)
        user.add_level_label(:profile)
        user.add_level_label(:document)
        level = 4
      when '4'
        user.after_confirmation
        user.add_level_label(:phone)
        user.add_level_label(:profile)
        user.add_level_label(:document)
        user.add_level_label(:second_document)
        user.add_level_label(:institutional)
        level = 6
      else
        "Error: wrong level"
      end
      count += 1
    rescue => e
      message = { error: e.message, email: row['Email'], account_id: row['AccountId'], composed_uid: composed_uid }
      errors_users_file.write(message.to_yaml + "\n")
      # we put users in DB as lvl 1 and state active - so they just need to reset pass and start KYC or trading
      # User.last.after_confirmation
    end
    errors_users_file.close
    Kernel.puts "Created #{count} members"
  end

  desc 'users affiliates relation from csv file'
  task :fill_affiliates => :environment do
    ### Parse options
    options = {}

    o = OptionParser.new

    o.banner = 'Usage: rake users:fill_affiliates -- -csv ~/Downloads/import_sheet.csv'
    o.on('--csv PATH', '--f pATH') { |path| options[:path] = path.to_s }

    args = o.order!(ARGV) {} # protect from wrong params
    o.parse!(args)

    csv_table = File.read(options[:path])
    errors_affiliates_file = File.open("errors_affiliates_file.txt", "w")
    CSV.parse(csv_table, :headers => true).map do |row|
      composed_cur_user_uid = "ID" + (1000000000 + row['AccountId'].to_i).to_s
      composed_target_uid = "ID" + (1000000000 + row['AffiliateId'].to_i).to_s

      target_user_id = User.find_by_uid!(composed_target_uid).id

      User.find_by_uid!(composed_cur_user_uid).update(referral_id: target_user_id)
    rescue => e
      message = { error: e.message, email: row['Email'], account_id: row['AccountId'], composed_uid: composed_uid }
      errors_affiliates_file.write(message.to_yaml + "\n")
    end
  end
end
