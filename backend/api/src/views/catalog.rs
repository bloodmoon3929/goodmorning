use serde::Serialize;

use super::product::ProductCard;
use crate::{
    models::catalog::{Character, Ip, IpStat},
    services::{
        catalog::{CharacterDetail, IpDetail},
        rules::type_label,
    },
};

#[derive(Serialize)]
pub struct IpView {
    pub id: i64,
    pub name: String,
    /// character · anime · game · plamodel
    pub category: String,
    pub image_url: Option<String>,
    pub aliases: Vec<String>,
}

impl From<Ip> for IpView {
    fn from(ip: Ip) -> Self {
        Self { id: ip.id, name: ip.name, category: ip.category, image_url: ip.image_url, aliases: ip.aliases }
    }
}

#[derive(Serialize)]
pub struct CharacterView {
    pub id: i64,
    pub ip_id: i64,
    pub name: String,
    pub image_url: Option<String>,
}

impl From<Character> for CharacterView {
    fn from(c: Character) -> Self {
        Self { id: c.id, ip_id: c.ip_id, name: c.name, image_url: c.image_url }
    }
}

#[derive(Serialize)]
pub struct IpStatView {
    pub ip: IpView,
    pub character_count: i64,
    pub goods_count: i64,
}

impl From<(Ip, IpStat)> for IpStatView {
    fn from((ip, s): (Ip, IpStat)) -> Self {
        Self { ip: ip.into(), character_count: s.character_count, goods_count: s.goods_count }
    }
}

#[derive(Serialize)]
pub struct IpDetailView {
    pub ip: IpView,
    pub characters: Vec<CharacterView>,
    pub products: Vec<ProductCard>,
}

impl From<IpDetail> for IpDetailView {
    fn from(d: IpDetail) -> Self {
        Self {
            ip: d.ip.into(),
            characters: d.characters.into_iter().map(Into::into).collect(),
            products: d.products.into_iter().map(Into::into).collect(),
        }
    }
}

#[derive(Serialize)]
pub struct GoodsGroup {
    #[serde(rename = "type")]
    pub kind: String,
    pub label: &'static str,
    pub products: Vec<ProductCard>,
}

#[derive(Serialize)]
pub struct CharacterDetailView {
    pub character: CharacterView,
    pub ip: IpView,
    pub goods_count: usize,
    pub online_count: usize,
    pub nearby_count: usize,
    pub groups: Vec<GoodsGroup>,
}

impl From<CharacterDetail> for CharacterDetailView {
    fn from(d: CharacterDetail) -> Self {
        let all = || d.groups.iter().flat_map(|(_, items)| items.iter());
        let goods_count = all().count();
        let online_count = all().filter(|s| s.online_malls > 0).count();
        let nearby_count = all().filter(|s| s.nearby_stores > 0).count();
        Self {
            character: d.character.into(),
            ip: d.ip.into(),
            goods_count,
            online_count,
            nearby_count,
            groups: d
                .groups
                .into_iter()
                .map(|(kind, items)| GoodsGroup { label: type_label(&kind), kind, products: items.into_iter().map(Into::into).collect() })
                .collect(),
        }
    }
}
