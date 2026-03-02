from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import Field
from typing import List


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    database_url: str = Field(default="sqlite:///./production_app.db", alias="DATABASE_URL")
    jwt_secret: str = Field(default="change_this_in_production", alias="JWT_SECRET")
    jwt_expire_minutes: int = Field(default=720, alias="JWT_EXPIRE_MINUTES")
    shift_order: str = Field(default="A,B,C", alias="SHIFT_ORDER")
    cors_origins: str = Field(default="*", alias="CORS_ORIGINS")
    seed_demo: bool = Field(default=True, alias="SEED_DEMO")

    def shift_order_list(self) -> List[str]:
        return [s.strip() for s in self.shift_order.split(",") if s.strip()]

    def cors_origins_list(self) -> List[str]:
        if self.cors_origins.strip() == "*":
            return ["*"]
        return [s.strip() for s in self.cors_origins.split(",") if s.strip()]


settings = Settings()
