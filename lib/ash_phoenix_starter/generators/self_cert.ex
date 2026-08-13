defmodule AshPhoenixStarter.SelfCertGenerator do
  @doc """
  Generates a local Root CA, then uses it to issue and sign a server
  certificate for localhost and 127.0.0.1, outputting an explicit CA file.
  """

  @strength 2048
  @valid 365
  @names ["localhost", "127.0.0.1"]

  def generate_self_signed(cert_dir \\ "priv/cert") do
    File.mkdir_p!(cert_dir)

    cert_path = Path.join(cert_dir, "selfsigned.pem")
    key_path = Path.join(cert_dir, "selfsigned_key.pem")
    ca_cert_path = Path.join(cert_dir, "ca.pem")

    if File.exists?(cert_path) && File.exists?(key_path) && File.exists?(ca_cert_path) do
      IO.puts("Certificates already exist at #{cert_dir}.")
    else
      IO.puts("Generating local Certificate Authority and server certificate...")

      # 1. Generate Root CA Key and Self-Signed CA Certificate
      ca_key = X509.PrivateKey.new_rsa(@strength)

      ca_cert =
        X509.Certificate.self_signed(
          ca_key,
          "/CN=AshPhoenixStarter Local Root CA",
          validity: @valid,
          template: :root_ca
        )

      # 2. Generate Server Private Key
      server_key = X509.PrivateKey.new_rsa(@strength)

      # 3. Issue and Sign the Server Certificate using the Local CA
      server_cert =
        X509.Certificate.new(
          X509.PublicKey.derive(server_key),
          "/CN=localhost",
          ca_cert,
          ca_key,
          validity: @valid,
          template: :server,
          extensions: [
            subject_alt_name: X509.Certificate.Extension.subject_alt_name(@names)
          ]
        )

      full_chain =
        X509.Certificate.to_pem(server_cert) <>
          "\n" <>
          X509.Certificate.to_pem(ca_cert)

      # 4. Write out the key, the full-chain cert bundle (server cert + CA cert), and standalone CA
      File.write!(key_path, X509.PrivateKey.to_pem(server_key))

      File.write!(cert_path, full_chain)

      File.write!(ca_cert_path, X509.Certificate.to_pem(ca_cert))

      IO.puts("Successfully generated local CA and certificates in #{cert_dir}/")
    end
  end
end
