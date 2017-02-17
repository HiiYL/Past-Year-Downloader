require 'mechanize'
require "highline/import"
require 'daybreak'
require 'colorize'

class Subject
  def initialize(name, code)  
    # Instance variables  
    @name = name  
    @code = code  
  end
  def code
    @code
  end
  def name
    @name
  end
end
class Cipher

  def initialize(shuffled)
    normal = ('a'..'z').to_a + ('A'..'Z').to_a + ('0'..'9').to_a + [' ']
    @map = normal.zip(shuffled).inject(:encrypt => {} , :decrypt => {}) do |hash,(a,b)|
      hash[:encrypt][a] = b
      hash[:decrypt][b] = a
      hash
    end
  end

  def encrypt(str)
    str.split(//).map { |char| @map[:encrypt][char] }.join
  end

  def decrypt(str)
    str.split(//).map { |char| @map[:decrypt][char] }.join
  end

end

db = Daybreak::DB.new "mmls.db"
agent = Mechanize.new
agent.agent.http.verify_mode = OpenSSL::SSL::VERIFY_NONE
page = agent.get("https://mmls.mmu.edu.my")
form = page.form
puts "               #######################################"
puts "               |        PAST YEAR  DOWNLOADER        |"
puts "               |               BY                    |"
puts "               |          HII YONG LIAN              |"
puts "               #######################################"
if db.keys.include? 'mmls_password'
  puts "            ----------    Loaded MMLS Password --------  "
  form.stud_id = db['student_id']# INPUT YOUR STUDENT ID
  form.stud_pswrd = db['mmls_password']# INPUT YOUR MMLS PASSWORD
  page = agent.submit(form)
else
  loop do
    student_id = ask "Input Student ID: "
    mmls_password = ask("Input MMLS password (Input will be hidden): ") { |q| q.echo = false }

    form.stud_id = student_id# INPUT YOUR STUDENT ID
    form.stud_pswrd = mmls_password# INPUT YOUR MMLS PASSWORD
    page = agent.submit(form)
    if page.parser.xpath('//*[@id="alert"]').empty?
      db.set! 'student_id', student_id
      db.set! 'mmls_password', mmls_password
      break
    end
    retry_reply = ask("Student ID or password is invalid... Would you like to retry? (Y/N)")
    loop do
      if(retry_reply == 'Y' or retry_reply == 'y')
        break
      elsif(retry_reply == 'N' or retry_reply == 'n')
        db.close
        exit
      else
        retry_reply = ask("Unrecognized input... Would you like to retry? (Yy/Nn)")
      end
    end
  end
end
subject_links_urls = page.links_with(:text => /[A-Z][A-Z][A-Z][0-9][0-9][0-9][0-9] . [A-Z][A-Z][A-Z]/)
subjects = []
subject_links_urls.each do |link|
  subject = Subject.new(link.text.split(" (").first,link.text.split(" - ").first.gsub(/(?<=[A-Z])(?=\d+)/, ' '))
  subjects << subject
end
begin
  # cipher = Cipher.new ["K", "D", "w", "X", "H", "3", "e", "1", "S", "B", "g", "a", "y", "v", "I", "6", "u", "W", "C", "0", "9", "b", "z", "T", "A", "q", "U", "4", "O", "o", "E", "N", "r", "n", "m", "d", "k", "x", "P", "t", "R", "s", "J", "L", "f", "h", "Z", "j", "Y", "5", "7", "l", "p", "c", "2", "8", "M", "V", "G", "i", " ", "Q", "F"]
  agent.pluggable_parser.default = Mechanize::Download
  page = agent.get("http://library.mmu.edu.my.proxyvlib.mmu.edu.my/library2/diglib/exam_col/")
  form = page.form
  # form.user = "1141125087"
  # form.pass = cipher.decrypt "KDwc28MVG"
  # page = agent.submit(form)
  # form = page.form
  # db.close
  subjects.each do |subject|
    puts "Current Subject: " + subject.name
    form.rt = subject.code
    directory = subject.name + "/"
    page = agent.submit(form)
    page.links_with(text: "Fulltext View").each do |link|
      begin
        download_page = link.click
        download_form = download_page.form
        file_name = download_form.xfile
        if Dir[directory + file_name].empty?  
          download_page = agent.submit(download_form)
          agent.submit(download_page.form).save(directory + file_name)
          puts "create ".green  + directory + file_name
        else
          puts "identical ".blue + file_name
        end
      rescue Mechanize::ResponseCodeError
        puts "error ".red + directory + file_name + " not found"
      end
    end
    puts
  end
rescue NoMethodError
  puts
  puts "ERROR".red
  puts "Password Invalid:".red + " Either your password is wrong or you have login too frequently"
  puts "Please retry after a couple of minutes"
  puts "If this issue persists, please contact me at yonglian146@gmail.com"
end
page = agent.get("http://library.mmu.edu.my.proxyvlib.mmu.edu.my/library2/diglib/exam_col/exit.php") # Logout after done