require 'facter'
Facter.add(:dynatrace_oneagent_etag) do
  setcode do
    etag_filepattern = "/tmp/Dynatrace-OneAgent-Linux-*.sh.etag"
    match_file = Dir.glob(etag_filepattern)

    if match_file.any?
        puts File.read(match_file.first)
    else
        puts ''
    end
  end
end
