import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Atlas 项目内容档案",
  description: "按工作域、模块和版本浏览游戏项目需求、产出与源文件。",
  icons: {
    icon: "/favicon.svg",
    shortcut: "/favicon.svg",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="zh-CN">
      <body>{children}</body>
    </html>
  );
}
