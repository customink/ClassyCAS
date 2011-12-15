class ServiceTicket
  class << self
    def find!(ticket, store)
      username = store.hget(ticket, :username)
      service_url = store.hget(ticket, :service_url)
      
      if service_url && username
        store.del ticket
        new(service_url, username)
      end
    end
    
    def expire_time
      300
    end
  end
  
  attr_reader :username, :service_url
  
  def initialize(service_url, username)
    @service_url = service_url
    @username = username
  end
  
  def valid_for_service?(url)
    url = Addressable::URI.parse(url)

    # Don't include query strings in validation
    service_url == url.omit(:query).to_s
  end
  
  def ticket
    @ticket ||= "ST-#{rand(100000000000000000)}".to_s
  end
  
  def remaining_time(store)
    store.ttl ticket
  end
  
  def save!(store)

    store.pipelined do 
      store.hset ticket, :service_url, self.service_url
      store.hset ticket, :username, self.username
      store.expire ticket, self.class.expire_time
    end
    
  end
end