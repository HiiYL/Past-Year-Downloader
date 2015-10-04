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
db = Daybreak::DB.new "mmls.db"
agent = Mechanize.new
agent.agent.http.verify_mode = OpenSSL::SSL::VERIFY_NONE
page = agent.get("https://mmls.mmu.edu.my")
form = page.form
puts "               #######################################"
puts "               |         MMLS      DOWNLOADER        |"
puts "               |               BY                    |"
puts "               |           HII YONG LIAN             |"
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
db.close
subject_links_urls = page.links_with(:text => /[A-Z][A-Z][A-Z][0-9][0-9][0-9][0-9] . [A-Z][A-Z][A-Z]/)
subjects = []
subject_links_urls.each do |link|
  subject = Subject.new(link.text.split(" (").first,link.text.split(" - ").first.gsub(/(?<=[A-Z])(?=\d+)/, ' '))
  subjects << subject
end
agent.pluggable_parser.default = Mechanize::Download
page = agent.get("http://library.mmu.edu.my.proxyvlib.mmu.edu.my/library2/diglib/exam_col/")
form = page.form
form.user = "1141125087"
form.pass = "abc123456"
page = agent.submit(form)
form = page.form
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
page = agent.get("http://library.mmu.edu.my.proxyvlib.mmu.edu.my/library2/diglib/exam_col/exit.php") # Logout after done