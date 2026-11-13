import * as tus from "../../vendor/tus.min.js";

const TusUploader = {
  mounted() {
    const input = this.el.querySelector("#tus-file-input");
    const endpoint = this.el.dataset.endpoint || "/files";
    const chunkSize = parseInt(this.el.dataset.chunkSize || "5242880", 10);

    input.addEventListener("change", (e) => {
      const file = e.target.files[0];
      if (!file) return;

      this.pushEvent("upload_started", { filename: file.name });

      const upload = new tus.Upload(file, {
        endpoint: endpoint,
        chunkSize: chunkSize,
        retryDelays:,
        metadata: {
          filename: file.name,
          filetype: file.type || "application/octet-stream",
        },
        onError: (error) => {
          this.pushEvent("upload_error", {
            message: error.message || "Upload failed",
          });
          input.value = "";
        },
        onProgress: (bytesUploaded, bytesTotal) => {
          const percentage = Math.round((bytesUploaded / bytesTotal) * 100);
          this.pushEvent("upload_progress", { progress: percentage });
        },
        onSuccess: () => {
          this.pushEvent("upload_complete", {});
          input.value = "";
        },
      });

      upload.start();
    });
  },
};

export default TusUploader;
