class Api::V1::Internal::SystemController < Api::ServiceController

  # GET /api/v1/internal/system/status
  def status
    render json: {
      status: 'ok',
      service: 'evo-ai-crm',
      version: Evolution.config[:version],
      timestamp: Time.current.iso8601,
      authentication_method: Current.authentication_method,
      services: {
        redis: redis_status,
        postgres: postgres_status
      }
    }
  end

  # GET /api/v1/internal/system/health
  def health
    render json: {
      healthy: true,
      checks: {
        redis: redis_health_check,
        postgres: postgres_health_check
      },
      timestamp: Time.current.iso8601
    }
  end

  private

  def redis_status
    r = Redis.new(Redis::Config.app)
    'ok' if r.ping
  rescue Redis::CannotConnectError
    'failing'
  end

  def postgres_status
    ActiveRecord::Base.connection.active? ? 'ok' : 'failing'
  rescue ActiveRecord::ConnectionNotEstablished
    'failing'
  end

  def redis_health_check
    {
      status: redis_status,
      connection_pool: (Redis::Config.app.size rescue 'unknown')
    }
  end

  def postgres_health_check
    {
      status: postgres_status,
      active_connections: (ActiveRecord::Base.connection_pool.stat rescue {})
    }
  end
end