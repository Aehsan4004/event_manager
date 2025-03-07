require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'time'


def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5,"0")[0..4]
end

def clean_phone_number(phone)
  digits = phone.gsub(/\D/, '') # Remove non-digit characters

  case digits.length
  when 10
    digits
  when 11
    digits.start_with?('1') ? digits[1..] : 'Invalid'
  else
    'Invalid'
  end
end

# Method to analyze peak registration hours
def registration_hours(contents)
  hours = Hash.new(0)
  
  contents.each do |row|
    reg_time = Time.strptime(row[:regdate], "%m/%d/%y %H:%M") # Parse time
    hours[reg_time.hour] += 1
  end

  sorted_hours = hours.sort_by { |_, count| -count } # Sort by frequency (descending)
  sorted_hours.each { |hour, count| puts "Hour: #{hour}, Registrations: #{count}" }
end


def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = File.read('secret.key').strip

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id,form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

puts 'EventManager initialized.'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  phone = clean_phone_number(row[:homephone])
  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id,form_letter)

  registration_hours(contents)

end

