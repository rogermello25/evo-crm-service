class AgentBotPresenter < SimpleDelegator
  def access_token
    super&.token
  end
end
