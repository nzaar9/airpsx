package hx.well.route;
import hx.well.route.RouteGroup;
import hx.well.route.Route;
import hx.well.handler.UploadHandler;
import hx.well.http.ResponseStatic;
import hx.well.handler.pkg.UploadPackageHandler;
import hx.well.handler.pkg.ReceivePackageHandler;
import hx.well.handler.pkg.InstallPackageHandler;
import hx.well.handler.filesystem.FileSystemListHandler;
import hx.well.handler.filesystem.FileSystemExecutePayloadHandler;
import hx.well.handler.filesystem.FileSystemDownloadHandler;
import hx.well.handler.filesystem.FileSystemUploadHandler;
import hx.well.handler.filesystem.FileSystemStreamHandler;
import hx.well.handler.system.SystemStatusHandler;
import hx.well.handler.system.SystemInfoHandler;
import hx.well.handler.CPUStatisticsHandler;
import hx.well.handler.profile.ProfileListHandler;
import hx.well.handler.profile.ProfileImageHandler;
import hx.well.handler.TitleImageHandler;
import hx.well.handler.filesystem.StorageInfoHandler;
import hx.well.handler.ProcessListHandler;
import hx.well.handler.media.MediaListHandler;
import hx.well.handler.media.MediaThumbnailHandler;
import hx.well.handler.media.MediaStreamHandler;
import hx.well.handler.application.ApplicationListHandler;
import hx.well.handler.application.ApplicationRunHandler;
import hx.well.handler.save.SaveBackupHandler;
import hx.well.handler.task.TaskCreateHandler;
import hx.well.handler.task.TaskDeleteHandler;
import hx.well.handler.task.TaskDetailHandler;
import hx.well.handler.task.TaskListHandler;
import hx.well.handler.task.TaskUpdateHandler;
import hx.well.handler.task.TaskStatusHandler;
import hx.well.handler.task.TaskLogHandler;
import hx.well.handler.stats.StatsHistoryHandler;
import hx.well.handler.stats.StatsPlaytimeHandler;
import hx.well.handler.stats.AlertSettingsHandler;
import hx.well.handler.decrypt.DecryptEnqueueHandler;
import hx.well.handler.decrypt.DecryptListHandler;
import hx.well.handler.decrypt.DecryptCancelHandler;
import hx.well.handler.pkg.InstallQueueAddHandler;
import hx.well.handler.pkg.InstallQueueListHandler;
import hx.well.handler.pkg.InstallQueueCancelHandler;
import hx.well.handler.pkg.PackagePreviewHandler;
import hx.well.handler.filesystem.FileSystemUploadSessionInitHandler;
import hx.well.handler.filesystem.FileSystemUploadSessionChunkHandler;
import hx.well.handler.filesystem.FileSystemUploadSessionStatusHandler;
import hx.well.handler.filesystem.FileSystemUploadSessionCancelHandler;
import hx.well.handler.save.SaveBackupConfigHandler;
import hx.well.handler.save.SaveBackupRunHandler;
import hx.well.handler.save.SaveBackupListHandler;
import hx.well.handler.save.SaveBackupRestoreHandler;
import hx.well.handler.save.SaveBackupDeleteHandler;
import hx.well.handler.filesystem.FileSystemSearchHandler;
import hx.well.handler.filesystem.FileSystemRenameHandler;
import hx.well.handler.filesystem.FileSystemBatchHandler;
import hx.well.handler.filesystem.FileSystemArchiveHandler;
import hx.well.handler.filesystem.FileSystemJobHandler;
import hx.well.handler.filesystem.FileSystemTextHandler;
import hx.well.handler.filesystem.FileSystemHexHandler;
import hx.well.handler.ProcessKillHandler;
import hx.well.handler.ApiDocsHandler;
import hx.well.handler.application.ApplicationUninstallHandler;
import hx.well.handler.system.MaintenanceHandler;
import hx.well.handler.KillServerHandler;
import hx.well.handler.BlankHandler;
import hx.well.handler.script.remote.RemoteScriptListHandler;
import hx.well.handler.script.remote.RemoteScriptImageHandler;
import hx.well.handler.script.remote.RemoteScriptExecuteHandler;
import hx.well.handler.script.remote.RemoteScriptHeartbeatHandler;
import hx.well.handler.script.ScriptExecutorHandler;
import hx.well.http.ResponseBuilder;
import hx.well.handler.pkg.UploadInitPackageHandler;
import hx.well.handler.pkg.UploadListPackageHandler;
import hx.well.handler.pkg.UploadCancelPackageHandler;
import hx.well.handler.filesystem.FileSystemTempFileHandler;
using hx.well.tools.RouteElementTools;

class ApiRoute extends RouteGroup {
    public function template():Void {
        Route.get("/upload")
            .handler(new UploadHandler())
            .setStream(true);

        Route.path("/package").group(() -> {
            Route.get("/{file}.crc")
                .handle((a) -> {
                    trace("error");
                    return ResponseBuilder.asString("", 404);
                }).where("file", "[A-Z]{2}[0-9]{4}-[A-Z]{4}[0-9]{5}_[0-9]{2}-[A-Z0-9]{16}");

            Route.post("/upload/init")
                .handler(new UploadInitPackageHandler());

            Route.post("/upload/cancel")
                .handler(new UploadCancelPackageHandler());

            Route.post("/upload/list")
                .handler(new UploadListPackageHandler());

            Route.post("/upload")
                .handler(new UploadPackageHandler())
                .setStream(true);

            // Console only API, do not call from web!
            Route.get("/{sessionKey}.pkg")
                .handler(new ReceivePackageHandler())
                .where("sessionKey", "[\\-_0-9a-zA-Z]{32}");

            Route.post("/install")
                .handler(new InstallPackageHandler());

            Route.post("/preview")
                .handler(new PackagePreviewHandler());

            Route.post("/queue/add")
                .handler(new InstallQueueAddHandler());

            Route.get("/queue/list")
                .handler(new InstallQueueListHandler());

            Route.post("/queue/cancel")
                .handler(new InstallQueueCancelHandler());
        });

        Route.path("/fs").group(() -> {
            Route.post("/list")
                .handler(new FileSystemListHandler());

            Route.post("/payload")
                .handler(new FileSystemExecutePayloadHandler());

            Route.get("/download/{encodedPath}")
                .handler(new FileSystemDownloadHandler())
                .where("encodedPath", "(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$"); //Validate Base64 Regex

            Route.post("/upload/{path}")
                .handler(new FileSystemUploadHandler())
                .setStream(true)
                .where("path", ".*");

            Route.post("/rename")
                .handler(new FileSystemRenameHandler());

            Route.post("/search")
                .handler(new FileSystemSearchHandler());

            Route.post("/batch")
                .handler(new FileSystemBatchHandler());

            Route.post("/archive")
                .handler(new FileSystemArchiveHandler());

            Route.get("/job")
                .handler(new FileSystemJobHandler());

            Route.post("/text")
                .handler(new FileSystemTextHandler());

            Route.post("/hex")
                .handler(new FileSystemHexHandler());

            Route.post("/upload-session/init")
                .handler(new FileSystemUploadSessionInitHandler());

            Route.post("/upload-session/chunk")
                .handler(new FileSystemUploadSessionChunkHandler())
                .setStream(true);

            Route.get("/upload-session/status")
                .handler(new FileSystemUploadSessionStatusHandler());

            Route.post("/upload-session/cancel")
                .handler(new FileSystemUploadSessionCancelHandler());

            Route.post("/temp/file")
                .handler(new FileSystemTempFileHandler())
                .setStream(true);

            Route.get("/stream/{path}")
                .handler(new FileSystemStreamHandler())
                .where("path", ".*");
        });

        #if orbis
        Route.path("/system").group(() -> {
            Route.get("/status")
                .handler(new SystemStatusHandler());

            Route.get("/info")
                .handler(new SystemInfoHandler());

            Route.get("/stats")
                .handler(new CPUStatisticsHandler());
        });

        Route.path("/profile").group(() -> {
            Route.get("/list")
                .handler(new ProfileListHandler());

            // TODO: Add regex to profileId
            Route.get("/image/{profileId}")
                .handler(new ProfileImageHandler())
                .where("profileId", "[0-9a-f]{8}");
        });

        Route.path("/title").group(() -> {
            Route.get("/image/{titleId}")
                .handler(new TitleImageHandler())
                .where("titleId", "[A-Z]{4}[0-9]{5}");
        });

        Route.get("/storage/info")
            .handler(new StorageInfoHandler());

        Route.get("/process/list")
            .handler(new ProcessListHandler());

        Route.post("/process/kill")
            .handler(new ProcessKillHandler());

        Route.path("/media").group(() -> {
            Route.get("/list")
                .handler(new MediaListHandler());

            Route.get("/thumbnails/{path}")
                .handler(new MediaThumbnailHandler())
                .where("path", ".*");

            Route.get("/{path}")
                .handler(new MediaStreamHandler())
                .where("path", ".*");
        });

        Route.path("/app").group(() -> {
            Route.get("/list")
                .handler(new ApplicationListHandler());

            Route.post("/uninstall/{titleId}")
                .handler(new ApplicationUninstallHandler())
                .where("titleId", "[A-Z]{4}[0-9]{5}");

            Route.get("/run/{titleId}")
                .handler(new ApplicationRunHandler())
                .where("titleId", "[A-Z]{4}[0-9]{5}");
        });

        Route.get("/save/backup/{profileId?}")
            .handler(new SaveBackupHandler())
            .where("profileId", "[0-9a-f]{8}");

        Route.path("/save/backups").group(() -> {
            Route.post("/config")
                .handler(new SaveBackupConfigHandler());

            Route.post("/run")
                .handler(new SaveBackupRunHandler());

            Route.get("/list")
                .handler(new SaveBackupListHandler());

            Route.post("/restore")
                .handler(new SaveBackupRestoreHandler());

            Route.post("/delete")
                .handler(new SaveBackupDeleteHandler());
        });
        #end

        Route.path("/task").group(() -> {
            Route.post("/create")
                .handler(new TaskCreateHandler());

            Route.post("/delete")
                .handler(new TaskDeleteHandler());

            Route.post("/detail")
                .handler(new TaskDetailHandler());

            Route.get("/list")
                .handler(new TaskListHandler());

            Route.post("/update")
                .handler(new TaskUpdateHandler());

            Route.get("/status")
                .handler(new TaskStatusHandler());

            Route.post("/log")
                .handler(new TaskLogHandler());
        });

        Route.path("/stats").group(() -> {
            Route.get("/history")
                .handler(new StatsHistoryHandler());

            Route.get("/playtime")
                .handler(new StatsPlaytimeHandler());

            Route.post("/alert")
                .handler(new AlertSettingsHandler());
        });

        #if orbis
        Route.path("/decrypt").group(() -> {
            Route.post("/enqueue")
                .handler(new DecryptEnqueueHandler());

            Route.get("/list")
                .handler(new DecryptListHandler());

            Route.post("/cancel")
                .handler(new DecryptCancelHandler());
        });
        #end

        Route.post("/system/maintenance")
            .handler(new MaintenanceHandler());

        Route.post("/server/kill")
            .handler(new KillServerHandler());

        Route.get("/docs")
            .handler(new ApiDocsHandler());

        Route.get("/blank")
            .handler(new BlankHandler());

        #if orbis
        Route.path("/script").group(() -> {
            Route.path("/remote").group(() -> {
                Route.get("/list")
                    .handler(new RemoteScriptListHandler());

                Route.get("/image/{key}")
                    .handler(new RemoteScriptImageHandler());

                Route.post("/execute")
                    .handler(new RemoteScriptExecuteHandler());

                Route.post("/heartbeat")
                    .handler(new RemoteScriptHeartbeatHandler());
            });

            Route.post("execute")
                .handler(new ScriptExecutorHandler());
        });
        #end
    }
}
