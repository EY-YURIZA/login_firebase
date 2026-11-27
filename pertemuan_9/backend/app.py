import json
import os
from flask import Flask, render_template_string, request
import firebase_admin
from firebase_admin import credentials, messaging

app = Flask(__name__)

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
KEY_PATH = os.path.join(BASE_DIR, "serviceAccountKey.json")

firebase_ready = False
if os.path.exists(KEY_PATH):
    if not firebase_admin._apps:
        cred = credentials.Certificate(KEY_PATH)
        firebase_admin.initialize_app(cred)
    firebase_ready = True

HTML_TEMPLATE = """
<!DOCTYPE html>
<html lang="id">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>FCM Notification Sender - Pertemuan 9</title>
  <style>
    body { font-family: system-ui, -apple-system, sans-serif; background: #f4f6f9; margin: 0; padding: 24px; }
    .container { max-width: 560px; margin: 0 auto; background: #fff; padding: 24px; border-radius: 12px; box-shadow: 0 2px 10px rgba(0,0,0,0.08); }
    h2 { margin-top: 0; color: #1e293b; }
    label { display: block; font-weight: 600; margin: 14px 0 6px; color: #334155; font-size: 14px; }
    input, select, textarea { width: 100%; box-sizing: border-box; padding: 10px 12px; border: 1px solid #cbd5e1; border-radius: 8px; font-size: 14px; }
    textarea { resize: vertical; font-family: monospace; }
    button { margin-top: 20px; width: 100%; padding: 12px; background: #2563eb; color: #fff; border: none; border-radius: 8px; font-size: 15px; font-weight: 600; cursor: pointer; }
    button:hover { background: #1d4ed8; }
    .alert { padding: 12px; border-radius: 8px; margin-bottom: 16px; font-size: 14px; word-break: break-all; }
    .success { background: #dcfce7; color: #166534; border: 1px solid #86efac; }
    .error { background: #fee2e2; color: #991b1b; border: 1px solid #fca5a5; }
    .hint { font-size: 12px; color: #64748b; margin-top: 4px; }
  </style>
</head>
<body>
  <div class="container">
    <h2>FCM Notification Sender</h2>

    {% if not firebase_ready %}
      <div class="alert error">
        File <b>serviceAccountKey.json</b> belum ditemukan di folder <code>backend/</code>. Silakan unduh dari Firebase Console terlebih dahulu.
      </div>
    {% endif %}

    {% if status %}
      <div class="alert {{ 'success' if success else 'error' }}">
        {{ status }}
      </div>
    {% endif %}

    <form method="POST">
      <label for="target_type">Jenis Tujuan</label>
      <select name="target_type" id="target_type" onchange="toggleTargetHint()">
        <option value="token" {{ 'selected' if form.target_type == 'token' else '' }}>Device Token (Satu HP)</option>
        <option value="topic" {{ 'selected' if form.target_type == 'topic' else '' }}>Topic (Semua Subscriber)</option>
      </select>

      <label for="target_value">FCM Token / Nama Topic</label>
      <input type="text" name="target_value" id="target_value" required
             placeholder="Tempel FCM Device Token atau ketik: kelas"
             value="{{ form.target_value }}">
      <div class="hint" id="target_hint">Tempel token yang disalin dari FcmTokenCard di aplikasi Flutter, atau pilih Topic dan isi <b>kelas</b>.</div>

      <label for="title">Judul Notifikasi (Title)</label>
      <input type="text" name="title" id="title" required
             placeholder="Contoh: Pengumuman Kuliah"
             value="{{ form.title }}">

      <label for="body">Isi Pesan (Body)</label>
      <textarea name="body" id="body" rows="3" required
                placeholder="Contoh: Besok perkuliahan dimulai pukul 08.00 WIB.">{{ form.body }}</textarea>

      <label for="extra_data">Data Tambahan JSON (Opsional)</label>
      <textarea name="extra_data" id="extra_data" rows="3"
                placeholder='{"pengirim": "Dosen", "mata_kuliah": "Mobile Programming"}'>{{ form.extra_data }}</textarea>
      <div class="hint">Akan tampil di halaman <b>Detail Notifikasi</b> saat notifikasi diklik.</div>

      <button type="submit">Kirim Notifikasi</button>
    </form>
  </div>

  <script>
    function toggleTargetHint() {
      const type = document.getElementById('target_type').value;
      const input = document.getElementById('target_value');
      if (type === 'topic' && !input.value) {
        input.value = 'kelas';
      }
    }
  </script>
</body>
</html>
"""


@app.route("/", methods=["GET", "POST"])
def index():
    status = None
    success = False
    form = {
        "target_type": "token",
        "target_value": "",
        "title": "",
        "body": "",
        "extra_data": '{"pengirim": "Admin", "info": "Tes Notifikasi FCM"}',
    }

    if request.method == "POST":
        form["target_type"] = request.form.get("target_type", "token")
        form["target_value"] = request.form.get("target_value", "").strip()
        form["title"] = request.form.get("title", "").strip()
        form["body"] = request.form.get("body", "").strip()
        form["extra_data"] = request.form.get("extra_data", "").strip()

        if not firebase_ready:
            status = "Gagal: serviceAccountKey.json tidak ditemukan."
        else:
            try:
                data_payload = {}
                if form["extra_data"]:
                    parsed = json.loads(form["extra_data"])
                    if not isinstance(parsed, dict):
                        raise ValueError("Data tambahan harus berupa objek JSON {key: value}.")
                    data_payload = {str(k): str(v) for k, v in parsed.items()}

                android_config = messaging.AndroidConfig(
                    priority="high",
                    notification=messaging.AndroidNotification(
                        channel_id="high_importance_channel",
                    ),
                )

                notif = messaging.Notification(
                    title=form["title"],
                    body=form["body"],
                )

                if form["target_type"] == "topic":
                    msg = messaging.Message(
                        notification=notif,
                        data=data_payload,
                        android=android_config,
                        topic=form["target_value"],
                    )
                else:
                    msg = messaging.Message(
                        notification=notif,
                        data=data_payload,
                        android=android_config,
                        token=form["target_value"],
                    )

                msg_id = messaging.send(msg)
                success = True
                status = f"Notifikasi berhasil dikirim! Message ID: {msg_id}"
            except Exception as e:
                success = False
                status = f"Gagal mengirim notifikasi: {e}"

    return render_template_string(
        HTML_TEMPLATE,
        firebase_ready=firebase_ready,
        status=status,
        success=success,
        form=form,
    )


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)