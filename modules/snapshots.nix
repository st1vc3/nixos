_:

{
  services.snapper = {
    snapshotInterval = "hourly";
    cleanupInterval = "1d";

    configs.root = {
      SUBVOLUME = "/";
      ALLOW_USERS = [ "stivce" ];

      TIMELINE_CREATE = true;
      TIMELINE_CLEANUP = true;
      TIMELINE_LIMIT_HOURLY = 24;
      TIMELINE_LIMIT_DAILY = 7;
      TIMELINE_LIMIT_WEEKLY = 4;
      TIMELINE_LIMIT_MONTHLY = 6;
      TIMELINE_LIMIT_YEARLY = 0;

      NUMBER_CLEANUP = true;
      NUMBER_LIMIT = 10;
      NUMBER_LIMIT_IMPORTANT = 10;
    };
  };
}
