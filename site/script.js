document.addEventListener('DOMContentLoaded', () => {
    const generateBtn = document.getElementById('generate-btn');
    const copyBtn = document.getElementById('copy-btn');
    const downloadBtn = document.getElementById('download-btn');
    const proxyOutput = document.getElementById('proxy-output');

    const ipCountInput = document.getElementById('ip-count');
    const loginInput = document.getElementById('login');
    const passwordInput = document.getElementById('password');
    const proxyTypeSelect = document.getElementById('proxy-type');
    // Inputs for network and mask are available if needed for more complex IP generation:
    // const networkInput = document.getElementById('network');
    // const maskInput = document.getElementById('mask');

    generateBtn.addEventListener('click', () => {
        const count = parseInt(ipCountInput.value) || 10;
        const login = loginInput.value || 'user';
        const password = passwordInput.value || 'pass';
        // const proxyType = proxyTypeSelect.value; // 'http' or 'socks5'
        // Currently, proxyType selection doesn't change the output format.
        // The generated format ip:port:login:password is common for both.
        // If specific formatting (e.g. http://user:pass@ip:port) is needed, this logic should be updated.

        let proxies = [];
        for (let i = 0; i < count; i++) {
            const ip = generateRandomIp();
            const port = generateRandomPort();
            proxies.push(`${ip}:${port}:${login}:${password}`);
        }
        proxyOutput.value = proxies.join('\n');
    });

    copyBtn.addEventListener('click', () => {
        if (proxyOutput.value) {
            proxyOutput.select();
            document.execCommand('copy');
            // Optionally, provide feedback to the user, e.g., change button text or show a tooltip.
            // alert('Proxies copied to clipboard!');
        }
    });

    downloadBtn.addEventListener('click', () => {
        if (proxyOutput.value) {
            const blob = new Blob([proxyOutput.value], { type: 'text/plain' });
            const url = URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = 'proxies.txt';
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
            URL.revokeObjectURL(url);
        }
    });

    function generateRandomIp() {
        // Generates a random public-like IP address.
        // This is a simplified generator. For specific network/mask, more complex logic is needed.
        return `${getRandomByte()}.${getRandomByte()}.${getRandomByte()}.${getRandomByte()}`;
    }

    function getRandomByte() {
        return Math.floor(Math.random() * 255) + 1; // Avoid 0 for simplicity here
    }

    function generateRandomPort() {
        // Generates a port typically used for proxies, avoiding well-known ports.
        return Math.floor(Math.random() * (60000 - 10000 + 1)) + 10000;
    }
});
