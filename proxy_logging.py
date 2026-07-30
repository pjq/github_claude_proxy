"""Custom litellm logging callback for the GitHub Copilot proxy.

Logs concise per-request diagnostics — outbound model, resolved API base,
integration-id headers, and (crucially) full failure details — so intermittent
issues like "unknown Copilot-Integration-Id" 400s can be traced without
patching the litellm library or enabling the very noisy set_verbose.

Wire it in config via:
    litellm_settings:
      callbacks: proxy_logging.copilot_logger
"""
import json
import sys


def _iid(headers):
    if not isinstance(headers, dict):
        return {}
    return {k: v for k, v in headers.items() if k.lower() == "copilot-integration-id"}


def _emit(tag, obj):
    print(f"[GHPROXY {tag}] " + json.dumps(obj, default=str)[:1200], file=sys.stderr, flush=True)


try:
    from litellm.integrations.custom_logger import CustomLogger

    class CopilotLogger(CustomLogger):
        def log_pre_api_call(self, model, messages, kwargs):
            lp = kwargs.get("litellm_params", {}) or {}
            headers = (kwargs.get("additional_args", {}) or {}).get("headers") or lp.get("headers") or {}
            iid = _iid(headers)
            _emit("request", {
                "model": model,
                "api_base": kwargs.get("api_base") or lp.get("api_base"),
                "custom_llm_provider": kwargs.get("custom_llm_provider"),
                "integration_id": iid,
                "integration_id_dup": len(iid) > 1,
            })

        async def async_log_failure_event(self, kwargs, response_obj, start_time, end_time):
            lp = kwargs.get("litellm_params", {}) or {}
            _emit("FAILURE", {
                "model": kwargs.get("model"),
                "api_base": kwargs.get("api_base") or lp.get("api_base"),
                "exception": str(kwargs.get("exception"))[:500],
                "status": getattr(kwargs.get("exception"), "status_code", None),
            })

        def log_failure_event(self, kwargs, response_obj, start_time, end_time):
            _emit("FAILURE", {
                "model": kwargs.get("model"),
                "exception": str(kwargs.get("exception"))[:500],
            })

    copilot_logger = CopilotLogger()
except Exception as e:  # pragma: no cover
    print(f"[GHPROXY] failed to init CopilotLogger: {e}", file=sys.stderr, flush=True)
    copilot_logger = None
