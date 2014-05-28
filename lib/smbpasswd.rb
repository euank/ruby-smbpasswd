require 'open3'
class Smbpasswd

  class SmbRunError < StandardError; end

  def initialize
    @args = []
    @pstdin = []
    @needs_root = false
  end
  def use_root(bool=true)
    @needs_root = bool
  end

  def run!
    execstr = 'smbpasswd'
    if Process.uid != 0
      $stderr.puts "Warning: operation requires root but not run as root; attempting to sudo"
      @args.unshift execstr
      execstr = "sudo"
    end
    stdout, stderr, status = Open3.capture3("#{execstr} #{@args.join(' ')}", 
                                            stdin_data: @pstdin.map{|x|x+"\n"}.join(''))

    if status != 0
      raise SmbRunError, ("status #{status.exitstatus}" +
                        (stderr.strip!.size > 0 ? ': ' + stderr : ''))
    end
    true
  end

  no_arg_flags = {
    L: :local_mode,
    i: :interdomain_account,
    s: :silent,
    m: :is_machine_account,
  }
  single_arg_flags = {
    c: :config_path,
    x: :delete,
    d: :disable,
    e: :enable,
    D: :debuglevel,
    n: :nullify,
    r: :remote_machine_name,
    R: :name_resolve_order,
    U: :username,
    w: :ldap_password,
  }
  require_root = [:a, :x, :d, :e, :n, :m, :i]

  no_arg_flags.each do |k,v|
    class_eval <<-EOM
      def #{v.to_s}
        @args << "-#{k.to_s}"
        if #{require_root.include? k}
          use_root
        end
        self
      end
    EOM
  end
  single_arg_flags.each do |k,v|
    class_eval <<-EOM
      def #{v.to_s}(arg)
        @args << "-#{k.to_s}" << arg
        if #{require_root.include? k}
          use_root
        end
        self
      end
    EOM
  end

  def ldap_password_stdin(pass)
    @args << '-w'
    @pstdin << pass
    self
  end

  def add(user, password)
    @args << '-s' << '-a' << user && use_root
    2.times{@pstdin << password}
    self
  end
end
