import type { Metadata, Viewport } from "next";
import { Inter, JetBrains_Mono } from "next/font/google";
import "./globals.css";
import {
  SITE_URL,
  SITE_NAME,
  SITE_TITLE,
  SITE_DESCRIPTION,
  GITHUB_URL,
} from "@/lib/site";

const inter = Inter({
  weight: ["400", "500", "600", "700"],
  subsets: ["latin"],
  variable: "--font-sans",
});

const jetbrainsMono = JetBrains_Mono({
  weight: ["400", "500"],
  subsets: ["latin"],
  variable: "--font-mono",
});

export const viewport: Viewport = {
  viewportFit: "cover",
  themeColor: "#000000",
};

export const metadata: Metadata = {
  title: {
    default: SITE_TITLE,
    template: `%s · ${SITE_NAME}`,
  },
  description: SITE_DESCRIPTION,
  metadataBase: new URL(SITE_URL),
  applicationName: SITE_NAME,
  keywords: [
    "voice journal",
    "offline transcription",
    "on-device transcription",
    "voice notes",
    "voice diary",
    "private journal",
    "speech to text",
    "iOS journal app",
  ],
  authors: [{ name: "theiskaa", url: "https://github.com/theiskaa" }],
  creator: "theiskaa",
  publisher: "theiskaa",
  formatDetection: {
    email: false,
    address: false,
    telephone: false,
  },
  alternates: {
    canonical: "/",
  },
  icons: {
    icon: [{ url: "/icon.svg", type: "image/svg+xml" }],
    apple: "/apple-icon.png",
  },
  openGraph: {
    title: SITE_TITLE,
    description: SITE_DESCRIPTION,
    siteName: SITE_NAME,
    type: "website",
    locale: "en_US",
    url: "/",
    images: [
      {
        url: "/og.png",
        width: 2400,
        height: 1350,
        alt: SITE_TITLE,
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    title: SITE_TITLE,
    description: SITE_DESCRIPTION,
    images: ["/og.png"],
  },
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      "max-video-preview": -1,
      "max-image-preview": "large",
      "max-snippet": -1,
    },
  },
};

const jsonLd = {
  "@context": "https://schema.org",
  "@type": "MobileApplication",
  name: SITE_NAME,
  operatingSystem: "iOS",
  applicationCategory: "UtilitiesApplication",
  description: SITE_DESCRIPTION,
  url: SITE_URL,
  license: "https://opensource.org/licenses/MIT",
  sameAs: [GITHUB_URL],
  author: {
    "@type": "Person",
    name: "theiskaa",
    url: "https://github.com/theiskaa",
  },
  offers: {
    "@type": "Offer",
    price: "0",
    priceCurrency: "USD",
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" className={`${inter.variable} ${jetbrainsMono.variable}`}>
      <body>
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
        />
        {children}
      </body>
    </html>
  );
}
