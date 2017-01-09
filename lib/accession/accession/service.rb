module Accession
  class Service
    include ActiveModel::Validations

    PROVIDERS = { "managed" => :EGA, "open" => :ENA }

    attr_reader :provider

    validates_presence_of :provider

    def initialize(study_type = nil)
      @provider = PROVIDERS[study_type]
    end

    def ena?
      provider == :ENA
    end

    def ega?
      provider == :EGA
    end

    def visibility
      ena? ? "HOLD" : "PROTECT"
    end

    def broker
      ega? ? provider.to_s : ""
    end

    def url
      if valid?
        return set_url(configatron.accession.ena.user) if ena?
        return set_url(configatron.accession.ega.user) if ega?
      end
    end

  private

    def set_url(provider)
      URI.parse(configatron.accession.url + provider).to_s
    end
  end
end
