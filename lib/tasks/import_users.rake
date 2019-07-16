
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

    csv_table = File.read(options[:path])
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

      # we put users in DB as lvl 1 and state active - so they just need to reset pass and start KYC or trading
      User.last.after_confirmation
    end
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
    CSV.parse(csv_table, :headers => true).map do |row|
      composed_cur_user_uid = "ID" + (1000000000 + row['AccountId'].to_i).to_s
      composed_target_uid = "ID" + (1000000000 + row['AffiliateId'].to_i).to_s

      target_user_id = User.find_by_uid(composed_target_uid).id

      User.find_by_uid(composed_cur_user_uid).update(referral_id: target_user_id)
    end
  end
end
