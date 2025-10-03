    level=getattr(logging, LOG_LEVEL.upper(), logging.INFO),
    datefmt="%Y-%m-%d %H:%M:%S",
logger.info("Configuration loaded - Data dir: %s | Log level: %s", DATA_DIR, LOG_LEVEL)
