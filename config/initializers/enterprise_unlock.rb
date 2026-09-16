module ChatwootHubEnterprisePatch
  def pricing_plan
    'enterprise'
  end

  def pricing_plan_quantity
    100_000
  end
end

Rails.application.config.after_initialize do
  ChatwootHub.singleton_class.prepend(ChatwootHubEnterprisePatch)
end
