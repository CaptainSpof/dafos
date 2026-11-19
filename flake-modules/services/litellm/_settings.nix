# LiteLLM's config.yaml, shared by the dafpi wrapper (./litellm.nix) and the
# stack's vm-test, so an image bump is tested against the real config.
{
  model_list = [
    {
      # Same name as on Ollama, so a client only swaps the endpoint.
      model_name = "gemma4:12b";
      litellm_params = {
        # dafbox's GPU Ollama (fixed lease); 32k context set server-side.
        model = "openai/gemma4:12b";
        api_base = "http://192.168.0.12:11434/v1";
        api_key = "ollama";
      };
    }
  ]
  # dafoltop's CPU Ollama (its firewall lets dafpi alone in), for pi workers
  # on dafbox (modules/home/programs/ai). Ollama's default 4k context applies.
  ++ map
    (name: {
      model_name = name;
      litellm_params = {
        model = "openai/${name}";
        api_base = "http://192.168.0.10:11434/v1";
        api_key = "ollama";
      };
    })
    [
      "qwen2.5:3b"
      "qwen2.5:7b"
    ];

  # A whole chapter takes ~80 s on the GPU; X-Ray itself waits up to 10 min.
  litellm_settings.request_timeout = 600;

  general_settings = {
    # Full prompt and response in the UI's Logs page (which book: the X-Ray
    # prompt opens with "Livre : <title>").
    store_prompts_in_spend_logs = true;
  };
}
