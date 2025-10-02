const {defineConfig} = require('@vue/cli-service');
module.exports = defineConfig({
    publicPath: '/', // 정적 경로는 루트 기준
    transpileDependencies: true,
    devServer: {
        port: 5173, // 개발 서버 포트
    },
});
