# ================= 第一阶段：构建环境 (Builder) =================
FROM kalilinux/kali-rolling:latest AS builder

ENV DEBIAN_FRONTEND=noninteractive
ENV GOPATH=/root/go
ENV PATH="/root/.cargo/bin:/usr/local/go/bin:${GOPATH}/bin:${PATH}"

# 1. 安装基础构建工具
RUN apt-get update && apt-get install -y \
    curl wget git unzip build-essential golang-go rustc cargo libssl-dev libffi-dev

# 2. 编译/下载 Go 工具 (全量包含你要求的工具)
RUN go install github.com/projectdiscovery/httpx/cmd/httpx@latest && \
    go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest && \
    go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest && \
    go install github.com/ffuf/ffuf/v2@latest && \
    go install github.com/hahwul/dalfox/v2@latest && \
    go install github.com/OJ/gobuster/v3@latest && \
    go install github.com/aquasecurity/kube-bench@latest

# 3. 处理指定的 RustScan (zip -> tar.gz -> binary)
RUN wget "https://github.com/bee-san/RustScan/releases/download/2.4.1/x86_64-linux-rustscan.tar.gz.zip" -O /tmp/rustscan.zip && \
    unzip /tmp/rustscan.zip -d /tmp/ && \
    tar -zxvf /tmp/x86_64-linux-rustscan.tar.gz -C /tmp/ && \
    mv /tmp/rustscan /usr/local/bin/rustscan && \
    chmod +x /usr/local/bin/rustscan

# 4. 下载 Findomain (补充缺失的 Subdomain 工具)
RUN wget https://github.com/Findomain/Findomain/releases/latest/download/findomain-linux.zip -O /tmp/findomain.zip && \
    unzip /tmp/findomain.zip -d /usr/local/bin/ && \
    chmod +x /usr/local/bin/findomain

# 5. 预构建 CyberStrikeAI
WORKDIR /build/CyberStrikeAI
RUN git clone https://github.com/Ed1s0nZ/CyberStrikeAI.git . && \
    go mod download && \
    go build -o cyberstrike-ai cmd/server/main.go

# ================= 第二阶段：运行环境 (Runtime) =================
FROM kalilinux/kali-rolling:latest

ENV DEBIAN_FRONTEND=noninteractive
ENV PIP_INDEX_URL=https://pypi.org/simple
ENV GOPROXY=https://proxy.golang.org,direct
ENV PATH="/root/go/bin:${PATH}"

WORKDIR /opt/CyberStrikeAI

# 1. 安装 APT 工具 (移除了 msfvenom 和 zsteg，增加了 ruby)
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip python3-venv curl wget git sudo \
    # 增加 ruby 以支持 zsteg
    golang-go ruby ruby-dev \
    # 网络、Web、漏洞扫描
    nmap masscan arp-scan nbtscan sqlmap nikto dirb feroxbuster wpscan wafw00f xsser amass dnsenum fierce \
    # 渗透测试 (msfvenom 包含在 metasploit-framework 中)
    metasploit-framework gdb radare2 binwalk \
    # 密码与取证
    hashcat john foremost steghide exiftool \
    # 后渗透与 CTF
    impacket-scripts responder fcrackzip pdfcrack hash-identifier \
    # 容器安全
    trivy \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# 2. 安装 zsteg (通过 gem 安装)
RUN gem install zsteg

# 3. 从 Builder 拷贝所有二进制文件
COPY --from=builder /usr/local/bin/rustscan /usr/local/bin/rustscan
COPY --from=builder /usr/local/bin/findomain /usr/local/bin/findomain
COPY --from=builder /root/go/bin/ /usr/local/bin/
COPY --from=builder /build/CyberStrikeAI /opt/CyberStrikeAI

# 4. 配置 Python 虚拟环境并安装所有要求的安全库
RUN python3 -m venv venv && \
    ./venv/bin/pip install --no-cache-dir --upgrade pip && \
    ./venv/bin/pip install --no-cache-dir \
    # API Security
    arjun graphql-core api-fuzzer \
    # Cloud Security
    scoutsuite pacu terrascan checkov prowler cloudmapper \
    # Post-Exploitation & Binary
    pwntools ropper ROPGadget volatility3 \
    # 核心项目依赖
    -r requirements.txt || true

# 5. 补充 LinPeas 和 WinPeas
RUN mkdir -p /opt/tools && \
    wget https://github.com/peass-ng/PEASS-ng/releases/latest/download/linpeas.sh -O /opt/tools/linpeas.sh && \
    chmod +x /opt/tools/linpeas.sh

# 6. 设置执行权限
RUN chmod +x run.sh
# 暴露 CyberStrikeAI 可能用到的端口
EXPOSE 8080

ENTRYPOINT ["/bin/bash", "-c", "./run.sh"]
