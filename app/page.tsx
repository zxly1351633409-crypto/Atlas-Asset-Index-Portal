import type { Metadata } from "next";
import { AssetPortal } from "./AssetPortal";

export const metadata: Metadata = {
  title: "Atlas | 项目内容档案",
  description: "通过工作域、模块和版本轴浏览项目内容，并按需获取 VS/NAS 源文件。",
};

export default function Home() {
  return <AssetPortal />;
}
